#!/usr/bin/env python3
# flusso udp continuo per N secondi, con priorita' dichiarata dall'applicazione
# ogni pacchetto porta numero di sequenza e timestamp di partenza
# uso: tsn_stream.py <ip> <porta> <priorita> <secondi> <pps>   (pps 0 = a massima velocita')
import socket, struct, sys, time

ip       = sys.argv[1]
porta    = int(sys.argv[2])
priorita = int(sys.argv[3])
secondi  = float(sys.argv[4])
pps      = float(sys.argv[5])

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_PRIORITY, priorita)

pausa = 1.0 / pps if pps > 0 else 0
fine  = time.time() + secondi
n = 0

# 64 byte di payload: 8 di sequenza, 8 di timestamp, 48 di riempimento
while time.time() < fine:
    s.sendto(struct.pack("!QQ", n, time.time_ns()) + b"x" * 48, (ip, porta))
    n += 1
    if pausa:
        time.sleep(pausa)

print("INVIATI  %d pacchetti con SO_PRIORITY %d  (%.0f pkt/s)" % (n, priorita, n / secondi))
