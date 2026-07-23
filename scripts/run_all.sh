#! /bin/bash

# invoca in sequenza tutti gli script del prototipo
# eseguire come root dentro la VM:  sudo bash run_all.sh
cd "$(dirname "$0")"

# build di hostapd/wpa_supplicant/xdpfrer: solo se i binari mancano
ls /usr/local/sbin/hostapd /usr/local/bin/xdpfrer-native >/dev/null 2>&1 || bash install_dependecies.sh

echo "### 1/8  clean.sh"
bash clean.sh

echo "### 2/8  emulate_physic_layer.sh - regdb, dominio IT, 4 radio hwsim"
bash emulate_physic_layer.sh

echo "### 3/8  namesapace_setup.sh - netns, radio, veth, vlan, offload"
bash namesapace_setup.sh

echo "### 4/8  config_hostapd.sh - AP WPA3-SAE e associazione STA"
bash config_hostapd.sh

# wrapper_tc prima di taprio e frer: installa i qdisc ingress su cui si appoggiano
echo "### 5/8  wrapper_tc.sh - wrapping tc in ingresso"
bash wrapper_tc.sh

echo "### 6/8  launch_taprio.sh - taprio su vproxy-repl-in"
bash launch_taprio.sh

echo "### 7/8  launch_frer.sh - xdpfrer, prima elim poi repl"
bash launch_frer.sh

# ptp4l per ultimo: sporca le misure di latenza, fermalo con pkill prima dei test
echo "### 8/8  launch_ptp4l.sh - ptp sui quattro nodi"
bash launch_ptp4l.sh

echo "### lab pronto"
