#! /bin/bash
# questo script va eseguito se si sceglie di emulare il layer fisico (radio) con hwsim, senza usare radio reali

# istruzioni per aggiornare db di regolamentazione wireless (wireless-regdb) e caricare il modulo mac80211_hwsim con 4 radio virtuali che supportino 6ghz
apt-get install --reinstall -y wireless-regdb
# se apt non arriva ai repo, prendo i due file dalla cache dei .deb
ls /usr/lib/firmware/regulatory.db >/dev/null 2>&1 || dpkg-deb -x /var/cache/apt/archives/wireless-regdb_*.deb /tmp/regdb
ls /usr/lib/firmware/regulatory.db >/dev/null 2>&1 || install -m644 /tmp/regdb/lib/firmware/regulatory.db /tmp/regdb/lib/firmware/regulatory.db.p7s /usr/lib/firmware/

# ricarico cfg80211 per rileggere il regdb; prima vanno tolti i moduli dipendenti
modprobe -r mac80211_hwsim 2>/dev/null
modprobe -r mac80211 2>/dev/null
modprobe -r cfg80211 2>/dev/null
modprobe cfg80211
sleep 1
iw reg set IT
sleep 2
iw reg get | sed -n 2p

modprobe mac80211_hwsim use_system_clock=Y radios=4 && echo "mac80211_hwsim caricato con 4 radio virtuali (wlan0, wlan1, wlan2, wlan3)"

