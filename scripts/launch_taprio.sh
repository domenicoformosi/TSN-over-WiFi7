#! /bin/bash

# TAS / 802.1Qbv. Qui stanno solo i qdisc di egresso: i filtri di
# classificazione sono in wrapper_tc.sh, che possiede quelli di ingresso.

# skb->priority -> PCP nel tag, in uscita dal talker
ip netns exec talker ip link set dev wlan0.10 type vlan egress-qos-map 3:3 5:5

# taprio a 3 classi su vproxy-repl-in (creata con numtxqueues 3)
#   TC2  priority 5  finestra 0.1 ms  gate 04
#   TC1  priority 3  finestra 0.8 ms  gate 02
#   TC0  il resto    finestra 0.1 ms  gate 01
# ciclo 1 ms: il ritardo che il gate impone al traffico critico e' al massimo
# la sua finestra chiusa, cioe' 0.2 ms. Con ciclo 10 ms erano 2 ms e il costo
# del gate superava il beneficio (misurato).
ip netns exec bridge-repl tc qdisc replace dev vproxy-repl-in root taprio \
  num_tc 3 \
  map 0 0 0 1 0 2 0 0 0 0 0 0 0 0 0 0 \
  queues 1@0 1@1 1@2 \
  base-time 0 \
  sched-entry S 04 100000 \
  sched-entry S 02 800000 \
  sched-entry S 01 100000 \
  clockid CLOCK_TAI

# verifica: taprio rifiuta se real_num_tx_queues < num_tc
ip netns exec bridge-repl tc qdisc show dev vproxy-repl-in
ip netns exec bridge-repl ethtool -l vproxy-repl-in | tail -5
