#! /bin/bash

# test end-to-end del prototipo
# eseguire come root dentro la VM:  sudo bash test_prototipo.sh
cd "$(dirname "$0")"

mkdir -p /tmp/tsn_test
rm -f /tmp/tsn_test/*

echo "########## 0. RICOSTRUZIONE DEL LAB ##########"
# run_all.sh parte gia' da clean.sh
bash ../scripts/run_all.sh > /tmp/tsn_test/run_all.log 2>&1
grep -aE '^###|AP-ENABLED|^freq=|^wifi_generation|^wpa_state' /tmp/tsn_test/run_all.log
echo ""

echo "########## 1. FRER: duplicazione ed eliminazione ##########"
A0=$(ip netns exec bridge-repl ethtool -S veth-repl   | awk '/xdp_xmit:/{print $2; exit}')
B0=$(ip netns exec bridge-repl ethtool -S veth-repl-b | awk '/xdp_xmit:/{print $2; exit}')
P0=$(grep -a 'Passed:' /tmp/frer_elim.log | tail -1 | awk '{print $2}' | tr -dc 0-9)
D0=$(grep -a 'Passed:' /tmp/frer_elim.log | tail -1 | awk '{print $4}' | tr -dc 0-9)
ip netns exec talker ping -c 10 -i 0.3 -W 1 10.0.0.20 | tail -2
sleep 2
A1=$(ip netns exec bridge-repl ethtool -S veth-repl   | awk '/xdp_xmit:/{print $2; exit}')
B1=$(ip netns exec bridge-repl ethtool -S veth-repl-b | awk '/xdp_xmit:/{print $2; exit}')
P1=$(grep -a 'Passed:' /tmp/frer_elim.log | tail -1 | awk '{print $2}' | tr -dc 0-9)
D1=$(grep -a 'Passed:' /tmp/frer_elim.log | tail -1 | awk '{print $4}' | tr -dc 0-9)
echo ""
echo "replicazione  percorso A (veth-repl)   : $((A1-A0))"
echo "replicazione  percorso B (veth-repl-b) : $((B1-B0))"
echo "eliminazione  passati al listener      : $((P1-P0))"
echo "eliminazione  duplicati scartati       : $((D1-D0))"
echo ""

echo "########## 2. FRER: rimozione del percorso A ##########"
ip netns exec bridge-repl ip link set veth-repl down
echo "veth-repl abbattuta"
sleep 1
A0=$A1; B0=$B1
ip netns exec talker ping -c 10 -i 0.3 -W 1 10.0.0.20 | tail -2
sleep 2
A1=$(ip netns exec bridge-repl ethtool -S veth-repl   | awk '/xdp_xmit:/{print $2; exit}')
B1=$(ip netns exec bridge-repl ethtool -S veth-repl-b | awk '/xdp_xmit:/{print $2; exit}')
echo ""
echo "replicazione  percorso A (abbattuto)   : $((A1-A0))"
echo "replicazione  percorso B               : $((B1-B0))"
ip netns exec bridge-repl ip link set veth-repl up
echo "veth-repl ripristinata"
sleep 2
echo ""
echo "########## 3. TAPRIO: flusso critico continuo sotto interferenza ##########"
cp /tmp/ptp_repl.log /tmp/ptp_elim.log /tmp/ptp_talker.log /tmp/ptp_listener.log /tmp/tsn_test/
pkill ptp4l
sleep 1

echo "flusso critico: SO_PRIORITY 3 -> PCP 3 -> TC1, gate aperto 0.8 ms su 1"
echo "interferenza  : SO_PRIORITY 0 -> PCP 0 -> TC0, gate aperto 0.1 ms su 1"
echo ""

# Configurazione del collo di bottiglia
ip netns exec bridge-elim tc qdisc replace dev wlan2 root netem rate 10mbit limit 100
echo "collo di bottiglia: $(ip netns exec bridge-elim tc qdisc show dev wlan2 | head -1)"
echo "atteso: 80 pacchetti critici per finestra da 4 s"
echo ""

# ==================== SCENARIO 1: TAPRIO ====================
echo "--- con taprio ---"
# Lancia il monitoraggio preesistente in background e salva l'output
bash ./monitor_code.sh > /tmp/tsn_test/qdisc_taprio.log &
QMON=$!

ip netns exec listener stdbuf -oL python3 tsn_monitor.py 5000 24 4 &
MON=$!
sleep 1
ip netns exec talker python3 tsn_stream.py 10.0.0.20 5000 3 24 20 > /tmp/tsn_test/critico.txt 2>&1 &
CRIT=$!
sleep 11
echo ">>> parte l'interferenza best effort, a massima velocita'"
ip netns exec talker python3 tsn_stream.py 10.0.0.20 5001 0 8 0 > /tmp/tsn_test/flood.txt 2>&1
echo ">>> interferenza terminata"
wait $MON
wait $CRIT

# Ferma il monitoraggio
kill $QMON 2>/dev/null

cat /tmp/tsn_test/critico.txt
cat /tmp/tsn_test/flood.txt

echo ""
echo ">>> VISUALIZZAZIONE QUEUE METRICS (TAPRIO) <<<"
cat /tmp/tsn_test/qdisc_taprio.log
echo ""

# ==================== SCENARIO 2: PFIFO_FAST ====================
echo "--- controllo: stesso test senza taprio (pfifo_fast) ---"
ip netns exec bridge-repl tc qdisc replace dev vproxy-repl-in root pfifo_fast
sleep 1

# Lancia il monitoraggio in background per pfifo_fast
bash ./monitor_code.sh > /tmp/tsn_test/qdisc_pfifo.log &
QMON_PFIFO=$!

ip netns exec listener stdbuf -oL python3 tsn_monitor.py 5000 24 4 &
MON=$!
sleep 1
ip netns exec talker python3 tsn_stream.py 10.0.0.20 5000 3 24 20 >/dev/null 2>&1 &
CRIT=$!
sleep 11
echo ">>> parte l'interferenza best effort, a massima velocita'"
ip netns exec talker python3 tsn_stream.py 10.0.0.20 5001 0 8 0 >/dev/null 2>&1
echo ">>> interferenza terminata"
wait $MON
wait $CRIT

kill $QMON_PFIFO 2>/dev/null

echo ""
echo ">>> VISUALIZZAZIONE QUEUE METRICS (PFIFO_FAST) <<<"
cat /tmp/tsn_test/qdisc_pfifo.log
echo ""

ip netns exec bridge-elim tc qdisc del dev wlan2 root 2>/dev/null
bash ../scripts/launch_taprio.sh >/dev/null 2>&1
echo "collo di bottiglia rimosso, taprio ripristinato"
echo ""

echo "########## 4. PTP: elezione del grandmaster ##########"
echo -n "bridge-repl : "; grep -a 'grand master role' /tmp/tsn_test/ptp_repl.log | tail -1
echo -n "bridge-elim : "; grep -aE 'new foreign master|selected best master' /tmp/tsn_test/ptp_elim.log | tail -1
echo -n "talker      : "; grep -aE 'new foreign master|selected best master' /tmp/tsn_test/ptp_talker.log | tail -1
echo -n "listener    : "; grep -aE 'new foreign master|selected best master' /tmp/tsn_test/ptp_listener.log | tail -1
echo ""
echo "path delay misurato su ciascun nodo:"
echo -n "bridge-elim : "; grep -a 'path delay' /tmp/tsn_test/ptp_elim.log     | tail -1
echo -n "talker      : "; grep -a 'path delay' /tmp/tsn_test/ptp_talker.log   | tail -1
echo -n "listener    : "; grep -a 'path delay' /tmp/tsn_test/ptp_listener.log | tail -1
