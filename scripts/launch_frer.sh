#! /bin/bash

# pkill non stacca il programma XDP dall'interfaccia: senza queste righe un
# riavvio a caldo fallisce con "XDP program already attached"
pkill -f '[x]dpfrer-native'
sleep 1
ip netns exec bridge-repl ip link set dev vproxy-repl-out xdp off 2>/dev/null
ip netns exec bridge-repl ip link set dev veth-repl0       xdp off 2>/dev/null
ip netns exec bridge-repl ip link set dev veth-repl1       xdp off 2>/dev/null
ip netns exec bridge-elim ip link set dev veth-elim0       xdp off 2>/dev/null
ip netns exec bridge-elim ip link set dev veth-elim1       xdp off 2>/dev/null
ip netns exec bridge-elim ip link set dev vproxy-elim-in   xdp off 2>/dev/null

# elim per primo: attaccare XDP sulle veth-elim0 abilita NAPI su quelle
# interfacce, e senza NAPI sul lato ricevente veth_xdp_xmit() torna -ENXIO
ip netns exec bridge-elim stdbuf -oL -eL /usr/local/bin/xdpfrer-native -m elim -i veth-elim0:55 -i veth-elim1:56 -e vproxy-elim-in:20 >/tmp/frer_elim.log 2>&1 &
sleep 2

ip netns exec bridge-repl stdbuf -oL -eL /usr/local/bin/xdpfrer-native -m repl -i vproxy-repl-out:10 -e veth-repl0:55 -e veth-repl1:56 >/tmp/frer_repl.log 2>&1 &
sleep 2
