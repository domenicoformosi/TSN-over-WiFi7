#!/usr/bin/env bash

# pulizia totale, ogni giro riparte da zero

# i processi vanno chiusi prima dei namespace, altrimenti il netns non muore
pkill hostapd
pkill wpa_supplicant
pkill ptp4l
pkill -f '[x]dpfrer'
sleep 1

# cancellare il netns porta via interfacce, veth, vlan, qdisc e filtri che contiene
ip netns del talker 2>/dev/null
ip netns del bridge-repl 2>/dev/null
ip netns del bridge-elim 2>/dev/null
ip netns del listener 2>/dev/null
sleep 1

# le radio si ricreano in emulate_physic_layer.sh
modprobe -r mac80211_hwsim 2>/dev/null

echo "netns rimasti (deve essere vuoto):"
ip netns list
echo "pulizia completata"
