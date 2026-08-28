#!/usr/bin/env python3
# monitor continuo: una riga per finestra con latenza e pacchetti persi.
# i persi si contano dai numeri di sequenza, non si deducono dal conteggio:
# "attesi" e' l'intervallo di sequenza visto nella finestra.
# uso: tsn_monitor.py <porta> <secondi> <finestra>
import socket, struct, sys, time

porta    = int(sys.argv[1])
secondi  = float(sys.argv[2])
finestra = float(sys.argv[3])

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", porta))
s.settimeout(0.2)

def stampa(t, lat, seq):
    if not lat:
        print("t=%5.1fs   nessun pacchetto" % t)
        return
    attesi = max(seq) - min(seq) + 1
    persi  = attesi - len(seq)
    jitter = sum(abs(lat[i] - lat[i-1]) for i in range(1, len(lat))) / (len(lat) - 1) if len(lat) > 1 else 0.0
    print("t=%5.1fs   ricevuti %3d/%3d   persi %3d (%5.1f%%)   min %6.3f  avg %6.3f  max %6.3f  jitter %6.3f  ms"
          % (t, len(seq), attesi, persi, 100.0 * persi / attesi,
             min(lat), sum(lat) / len(lat), max(lat), jitter))

inizio   = time.time()
fine     = inizio + secondi
prossima = inizio + finestra
lat, seq = [], []
totale   = 0
primo    = None
ultimo   = None

while time.time() < fine:
    try:
        dati, _ = s.recvfrom(128)
        n, ts = struct.unpack("!QQ", dati[:16])
        lat.append((time.time_ns() - ts) / 1e6)
        seq.append(n)
        totale += 1
        primo  = n if primo  is None else min(primo, n)
        ultimo = n if ultimo is None else max(ultimo, n)
    except socket.timeout:
        pass
    if time.time() >= prossima:
        stampa(prossima - inizio, lat, seq)
        lat, seq = [], []
        prossima += finestra

if primo is not None:
    attesi = ultimo - primo + 1
    persi  = attesi - totale
    print("TOTALE       ricevuti %d/%d   persi %d (%.1f%%)"
          % (totale, attesi, persi, 100.0 * persi / attesi))
