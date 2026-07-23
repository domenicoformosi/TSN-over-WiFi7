#! /bin/bash

# aggiungo i singoli namespace e li attivo (lo up) per poterci lavorare dentro
ip netns add talker
ip netns add bridge-repl
ip netns add bridge-elim
ip netns add listener

ip netns exec talker ip link set dev lo up
ip netns exec bridge-repl ip link set dev lo up
ip netns exec bridge-elim ip link set dev lo up
ip netns exec listener ip link set dev lo up

# spostamento delle radio hwsim nei rispettivi namespace (permette di usare le interfacce wlanX dentro i namespace)
iw phy phy0 set netns name talker
iw phy phy1 set netns name bridge-repl
iw phy phy2 set netns name bridge-elim
iw phy phy3 set netns name listener

# configurazione degli indirizzi IP sulle interfacce radio hwsim (wlan0, wlan1, wlan2, wlan3) dentro i namespace talker, bridge-repl, bridge-elim e listener

ip netns exec talker ip addr replace 192.168.99.10/24 dev wlan0
ip netns exec bridge-repl ip addr replace 192.168.99.1/24 dev wlan1
ip netns exec talker ip link set dev wlan0 up
ip netns exec bridge-repl ip addr add 10.0.0.3/24 dev wlan1
ip netns exec bridge-repl ip link set dev wlan1 up
ip netns exec bridge-elim ip addr add 10.0.0.4/24 dev wlan2
ip netns exec bridge-elim ip link set dev wlan2 up
ip netns exec listener ip link set dev wlan3 up

# creo le vlan 10 e 20 dentro i namespace talker e listener, rispettivamente, per poterle usare come interfacce di rete virtuali (wlan0.10 e wlan3.20) per il test FRER

ip netns exec talker ip link add link wlan0 name wlan0.10 type vlan id 10
ip netns exec talker ip addr add 10.0.0.10/24 dev wlan0.10
ip netns exec talker ip link set dev wlan0.10 up

ip netns exec listener ip link add link wlan3 name wlan3.20 type vlan id 20
ip netns exec listener ip addr add 10.0.0.20/24 dev wlan3.20
ip netns exec listener ip link set dev wlan3.20 up

# creo veth necessarie per supportare wrapping e comunicazione tra namesapace

# talker 

ip netns exec talker ip link add ptp-tal0 type veth peer name ptp-tal1
ip netns exec talker ip link set ptp-tal0 address 02:00:00:00:00:00
# ipv6 spento sulle veth ptp e su quelle di ritorno
ip netns exec talker sysctl -qw net.ipv6.conf.ptp-tal0.disable_ipv6=1
ip netns exec talker sysctl -qw net.ipv6.conf.ptp-tal1.disable_ipv6=1
ip netns exec talker ip link set ptp-tal0 up
ip netns exec talker ip link set ptp-tal1 up

# mgmt: veth per sync ptp dei bridge
ip link add mgmt netns bridge-repl type veth peer name mgmt netns bridge-elim
ip netns exec bridge-repl sysctl -qw net.ipv6.conf.mgmt.disable_ipv6=1
ip netns exec bridge-elim sysctl -qw net.ipv6.conf.mgmt.disable_ipv6=1
ip netns exec bridge-repl ip link set mgmt up
ip netns exec bridge-elim ip link set mgmt up

# bridge-repl

# primo wrapper: wlan1 -> vproxy-repl-in, questo necessario per far funzionare xdp che altrimenti non accetterebbe i pacchetti
ip netns exec bridge-repl ip link add vproxy-repl-in numtxqueues 3 numrxqueues 3 type veth peer name vproxy-repl-out numtxqueues 3 numrxqueues 3
ip netns exec bridge-repl ip link set vproxy-repl-in up
ip netns exec bridge-repl ip link set vproxy-repl-out up

# secondo wrapper: wlan1 <-> ptp-repl1, server per far funzionare ptp
ip netns exec bridge-repl ip link add ptp-repl0 type veth peer name ptp-repl1
ip netns exec bridge-repl ip link set ptp-repl0 address 02:00:00:00:01:00
ip netns exec bridge-repl sysctl -qw net.ipv6.conf.ptp-repl0.disable_ipv6=1
ip netns exec bridge-repl sysctl -qw net.ipv6.conf.ptp-repl1.disable_ipv6=1
ip netns exec bridge-repl ip link set ptp-repl0 up
ip netns exec bridge-repl ip link set ptp-repl1 up

# veth per comunicazione listener -> talker senza duplicazione
ip link add veth-ret-elim netns bridge-elim type veth peer name veth-ret-repl netns bridge-repl
ip netns exec bridge-elim sysctl -qw net.ipv6.conf.veth-ret-elim.disable_ipv6=1
ip netns exec bridge-repl sysctl -qw net.ipv6.conf.veth-ret-repl.disable_ipv6=1
ip netns exec bridge-elim ip link set veth-ret-elim up
ip netns exec bridge-repl ip link set veth-ret-repl up

# veth frer: quelle sui cui avviene l'effettiva duplicazione
ip link add veth-repl netns bridge-repl type veth peer name veth-elim netns bridge-elim
ip link add veth-repl-b netns bridge-repl type veth peer name veth-elim-b netns bridge-elim
# eventualmete n...

ip netns exec bridge-repl ip link set veth-repl up
ip netns exec bridge-repl ip link set veth-repl-b up

# senza txvlan off il tag resta nei metadati skb e
# la radio trasmette un frame untagged
ip netns exec bridge-repl ethtool -K wlan1 txvlan off
ip netns exec bridge-repl ethtool -K vproxy-repl-out rxvlan off txvlan off
ip netns exec bridge-repl ethtool -K veth-repl rxvlan off txvlan off
ip netns exec bridge-repl ethtool -K veth-repl-b rxvlan off txvlan off
ip netns exec bridge-repl ethtool -K vproxy-repl-in txvlan off

# bridge-elim
# primo wrapper: vproxy-elim-in -> wlan2, questo necessario per far funzionare xdp che altrimenti non accetterebbe i pacchetti
ip netns exec bridge-elim ip link add vproxy-elim-in type veth peer name vproxy-elim-out
ip netns exec bridge-elim ip link set vproxy-elim-in up
ip netns exec bridge-elim ip link set vproxy-elim-out up

# secondo wrapper: wlan2 <-> ptp-elim1, server per far funzionare ptp
ip netns exec bridge-elim ip link add ptp-elim0 type veth peer name ptp-elim1
ip netns exec bridge-elim ip link set ptp-elim0 address 02:00:00:00:02:00
ip netns exec bridge-elim sysctl -qw net.ipv6.conf.ptp-elim0.disable_ipv6=1
ip netns exec bridge-elim sysctl -qw net.ipv6.conf.ptp-elim1.disable_ipv6=1
ip netns exec bridge-elim ip link set ptp-elim0 up
ip netns exec bridge-elim ip link set ptp-elim1 up

# veth frer lato elim: le coppie sono create nella sezione bridge-repl, qui alzo il peer
ip netns exec bridge-elim ip link set veth-elim up
ip netns exec bridge-elim ip link set veth-elim-b up

# senza txvlan off il tag resta nei metadati skb e
# la radio trasmette un frame untagged
ip netns exec bridge-elim ethtool -K veth-elim rxvlan off txvlan off
ip netns exec bridge-elim ethtool -K veth-elim-b rxvlan off txvlan off
ip netns exec bridge-elim ethtool -K vproxy-elim-in rxvlan off txvlan off
ip netns exec bridge-elim ethtool -K wlan2 txvlan off
ip netns exec bridge-elim ethtool -K vproxy-elim-out gro on

# listener
ip netns exec listener ip link add ptp-lis0 type veth peer name ptp-lis1
ip netns exec listener ip link set ptp-lis0 address 02:00:00:00:03:00
ip netns exec listener sysctl -qw net.ipv6.conf.ptp-lis0.disable_ipv6=1
ip netns exec listener sysctl -qw net.ipv6.conf.ptp-lis1.disable_ipv6=1
ip netns exec listener ip link set ptp-lis0 up
ip netns exec listener ip link set ptp-lis1 up
