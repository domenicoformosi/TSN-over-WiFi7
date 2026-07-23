#! /bin/bash

# INSTALLO VERSIONE HOSTAPD E WPA_SUPPLICANT CON SUPPORTO IEEE80211BE (WIFI7) E COMPILO
apt-get update -y
apt-get install -y build-essential git pkg-config libssl-dev libnl-3-dev libnl-genl-3-dev libnl-route-3-dev

# clono solo se manca, cosi' lo script si puo' rilanciare
ls /usr/local/src/hostap/.git >/dev/null 2>&1 || git clone --depth 1 --branch hostap_2_11 https://w1.fi/hostap.git /usr/local/src/hostap

cat > /usr/local/src/hostap/hostapd/.config <<'EOF'
CONFIG_DRIVER_NL80211=y
CONFIG_LIBNL32=y
CONFIG_CTRL_IFACE=y
CONFIG_CTRL_IFACE_UNIX=y
CONFIG_IEEE80211N=y
CONFIG_IEEE80211AC=y
CONFIG_IEEE80211AX=y
CONFIG_IEEE80211BE=y
CONFIG_SAE=y
CONFIG_IEEE80211W=y
CONFIG_ACS=y
EOF

make -C /usr/local/src/hostap/hostapd -j"$(nproc)"
install -m 0755 /usr/local/src/hostap/hostapd/hostapd /usr/local/sbin/hostapd
install -m 0755 /usr/local/src/hostap/hostapd/hostapd_cli /usr/local/sbin/hostapd_cli

cat > /usr/local/src/hostap/wpa_supplicant/.config <<'EOF'
CONFIG_DRIVER_NL80211=y
CONFIG_LIBNL32=y
CONFIG_CTRL_IFACE=y
CONFIG_CTRL_IFACE_UNIX=y
CONFIG_SAE=y
CONFIG_IEEE80211W=y
CONFIG_BACKEND=file
EOF

make -C /usr/local/src/hostap/wpa_supplicant -j"$(nproc)"
install -m 0755 /usr/local/src/hostap/wpa_supplicant/wpa_supplicant /usr/local/sbin/wpa_supplicant
install -m 0755 /usr/local/src/hostap/wpa_supplicant/wpa_cli /usr/local/sbin/wpa_cli

echo "hostapd e wpa_supplicant compilati e installati in /usr/local/sbin"

/usr/local/sbin/hostapd -v 2>&1 | head -1
/usr/local/sbin/wpa_supplicant -v 2>&1 | head -1

# INSTALLO XDPFRER 

apt-get install -y clang llvm libbpf-dev gcc-multilib
ln -sf /usr/include/x86_64-linux-gnu/asm /usr/include/asm
ls /usr/local/src/xdpfrer/.git >/dev/null 2>&1 || git clone --depth 1 https://github.com/EricssonResearch/xdpfrer.git /usr/local/src/xdpfrer
export PATH=/usr/local/sbin:$PATH

# forzo la modalita' xdp nativa nel sorgente: non c'e' un flag CLI
sed -i 's/attach_mode = XDP_MODE_SKB;/attach_mode = XDP_MODE_NATIVE;/' /usr/local/src/xdpfrer/src/xdpfrer.c
make -C /usr/local/src/xdpfrer/src clean
make -C /usr/local/src/xdpfrer/src
make -C /usr/local/src/xdpfrer/src install
# copia col nome che invoca launch_frer.sh
install -m 0755 /usr/local/src/xdpfrer/src/xdpfrer /usr/local/bin/xdpfrer-native

echo "xdpfrer compilato e installato in /usr/local/sbin, copia nativa in /usr/local/bin/xdpfrer-native"