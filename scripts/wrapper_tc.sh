#! /bin/bash

# wrapper ptp per talker

ip netns exec talker tc qdisc add dev ptp-tal1 ingress
ip netns exec talker tc filter add dev ptp-tal1 parent ffff: protocol all u32 match u32 0 0 at 0 action mirred egress redirect dev wlan0

ip netns exec talker tc qdisc add dev wlan0 ingress
# filtro su protocollo ptp (0x88f7)
ip netns exec talker tc filter add dev wlan0 parent ffff: protocol 0x88f7 prio 1 u32 match u32 0 0 at 0 action mirred egress redirect dev ptp-tal1

# wrapper per bridge-repl

# primo wrapper: wlan1 -> vproxy-repl-in, questo necessario per far funzionare xdp che altrimenti non accetterebbe i pacchetti
ip netns exec bridge-repl tc qdisc add dev wlan1 ingress

# copio il PCP del tag in skb->priority (il campo che legge taprio) e redirigo
#   prio 1  vlan 10 + pcp 5 -> TC2
#   prio 2  vlan 10 + pcp 3 -> TC1
#   prio 3  vlan 10         -> TC0 (fallback)
#   prio 4  ptp 0x88f7      -> wrapper ptp
ip netns exec bridge-repl tc filter add dev wlan1 ingress protocol 802.1Q prio 1 flower vlan_id 10 vlan_prio 5 action skbedit priority 5 pipe action mirred egress redirect dev vproxy-repl-in
ip netns exec bridge-repl tc filter add dev wlan1 ingress protocol 802.1Q prio 2 flower vlan_id 10 vlan_prio 3 action skbedit priority 3 pipe action mirred egress redirect dev vproxy-repl-in
ip netns exec bridge-repl tc filter add dev wlan1 ingress protocol 802.1Q prio 3 flower vlan_id 10 action mirred egress redirect dev vproxy-repl-in

# secondo wrapper: wlan1 <-> ptp-repl1, server per far funzionare ptp
# wlan1 -> ptp-repl1
# ip netns exec bridge-repl tc qdisc add dev wlan1 ingress eseguito prima
ip netns exec bridge-repl tc filter add dev wlan1 ingress protocol 0x88f7 prio 4 u32 match u32 0 0 at 0 action mirred egress redirect dev ptp-repl1
ip netns exec bridge-repl tc qdisc del dev ptp-repl1 ingress 2>/dev/null
# wlan1 -> ptp-repl1
ip netns exec bridge-repl tc qdisc add dev ptp-repl1 ingress
ip netns exec bridge-repl tc filter add dev ptp-repl1 ingress protocol all prio 1 u32 match u32 0 0 at 0 action mirred egress redirect dev wlan1


# veth per comunicazione listener -> talker senza duplicazione: cambio pacchetti vlan 20 -> vlan 10 e redirect su wlan1
ip netns exec bridge-repl tc qdisc add dev veth-ret-repl ingress
ip netns exec bridge-repl tc filter add dev veth-ret-repl ingress protocol 802.1Q flower vlan_id 20 action vlan modify id 10 pipe action mirred egress redirect dev wlan1

# bridge-elim

# primo wrapper: vproxy-elim-in -> wlan2, questo necessario per far funzionare xdp che altrimenti non accetterebbe i pacchetti
ip netns exec bridge-elim tc qdisc add dev vproxy-elim-out ingress
ip netns exec bridge-elim tc filter add dev vproxy-elim-out parent ffff: protocol all u32 match u32 0 0 at 0 action mirred egress redirect dev wlan2

# il qdisc di wlan2 va creato prima dei filtri che ci si appoggiano
ip netns exec bridge-elim tc qdisc add dev wlan2 ingress

# secondo wrapper: wlan2 <-> ptp-elim1, server per far funzionare ptp
ip netns exec bridge-elim tc filter add dev wlan2 ingress protocol 0x88f7 prio 2 u32 match u32 0 0 at 0 action mirred egress redirect dev ptp-elim1
ip netns exec bridge-elim tc qdisc add dev ptp-elim1 ingress
ip netns exec bridge-elim tc filter add dev ptp-elim1 ingress protocol all prio 1 u32 match u32 0 0 at 0 action mirred egress redirect dev wlan2


# veth per comunicazione listener -> talker senza duplicazione
# filtro pacchetti della vlan 20 (listener) e redirect su veth-ret-elim, che li invia direttamente a bridge-repl senza duplicazione
ip netns exec bridge-elim tc filter add dev wlan2 ingress protocol 802.1Q flower vlan_id 20 action mirred egress redirect dev veth-ret-elim

# wrapper ptp per listener
ip netns exec listener tc qdisc add dev wlan3 ingress
ip netns exec listener tc filter add dev wlan3 ingress protocol 0x88f7 prio 1 u32 match u32 0 0 at 0 action mirred egress redirect dev ptp-lis1

ip netns exec listener tc qdisc add dev ptp-lis1 ingress
ip netns exec listener tc filter add dev ptp-lis1 ingress protocol all prio 1 u32 match u32 0 0 at 0 action mirred egress redirect dev wlan3
