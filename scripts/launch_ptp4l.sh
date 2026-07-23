#! /bin/bash

cd "$(dirname "$0")"

# ptp4l legge le conf dal percorso passato con -f, quindi le copio in /etc
mkdir -p /etc/linuxptp
cp ptp4l_conf/*.conf /etc/linuxptp/

# lancio prima ptp4l su bridge-repl e bridge-elim, che sono i server ptp, poi lancio ptp4l su talker e listener, che sono i client ptp
ip netns exec bridge-repl stdbuf -oL -eL ptp4l -f /etc/linuxptp/ptp4l-repl.conf -m >/tmp/ptp_repl.log 2>&1 &
sleep 2
ip netns exec bridge-elim stdbuf -oL -eL ptp4l -f /etc/linuxptp/ptp4l-elim.conf -m >/tmp/ptp_elim.log 2>&1 &
ip netns exec talker stdbuf -oL -eL ptp4l -f /etc/linuxptp/ptp4l-talker.conf -m >/tmp/ptp_talker.log 2>&1 &
ip netns exec listener stdbuf -oL -eL ptp4l -f /etc/linuxptp/ptp4l-listener.conf -m >/tmp/ptp_listener.log 2>&1 &
sleep 35

# stato dei quattro nodi
echo "--- bridge-repl (grandmaster) ---"; tail -3 /tmp/ptp_repl.log
echo "--- bridge-elim ---";               tail -3 /tmp/ptp_elim.log
echo "--- talker ---";                    tail -3 /tmp/ptp_talker.log
echo "--- listener ---";                  tail -3 /tmp/ptp_listener.log
