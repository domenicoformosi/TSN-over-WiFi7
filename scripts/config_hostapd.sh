#! /bin/bash

# le conf sono in hostapd_conf/, relative a questo script
cd "$(dirname "$0")"

pkill hostapd
pkill wpa_supplicant
sleep 1

# avvio i due AP
ip netns exec bridge-repl /usr/local/sbin/hostapd hostapd_conf/hostapd-repl.conf -B
ip netns exec bridge-elim /usr/local/sbin/hostapd hostapd_conf/hostapd-elim.conf -B
sleep 3

# associo le due STA
ip netns exec talker /usr/local/sbin/wpa_supplicant -i wlan0 -c hostapd_conf/wpa_supplicant_talker.conf -B
ip netns exec listener /usr/local/sbin/wpa_supplicant -i wlan3 -c hostapd_conf/wpa_supplicant_listener.conf -B
sleep 6

echo "stato connessione talker:"
ip netns exec talker wpa_cli -i wlan0 status
echo "stato connessione listener:"
ip netns exec listener wpa_cli -i wlan3 status
