#!/bin/bash
# monitor_code.sh - Analisi in tempo reale delle Queue Metrics

IFACE="vproxy-repl-in"
NETNS="bridge-repl"
INTERVAL=1

echo "Avvio monitoraggio su $IFACE (netns: $NETNS)"
echo "Tempo      | Queue Depth   | Drops | Throughput (bps)"
echo "------------------------------------------------------"

PREV_BYTES=0
PREV_TIME=$(date +%s)

while true; do
    NOW=$(date +"%H:%M:%S")
    NOW_S=$(date +%s)

    # Cattura delle statistiche correnti della qdisc (Queueing Discipline)
    STATS=$(ip netns exec $NETNS tc -s qdisc show dev $IFACE 2>/dev/null)

    # 1. Queue Depth (backlog in byte e numero di pacchetti in coda)
    BACKLOG=$(echo "$STATS" | grep -oP 'backlog \K[0-9]+[a-zA-Z]* [0-9]+p' | head -n 1)
    [ -z "$BACKLOG" ] && BACKLOG="0b 0p"

    # 2. Packet Drop Rate (somma progressiva dei drop dovuti a buffer pieno)
    DROPS=$(echo "$STATS" | grep -oP 'dropped \K[0-9]+' | awk '{s+=$1} END {if (s=="") print 0; else print s}')

    # 3. Throughput (calcolo della variazione di byte inviati nel tempo)
    BYTES=$(echo "$STATS" | grep -oP 'Sent \K[0-9]+' | head -n 1)
    [ -z "$BYTES" ] && BYTES=0

    # calcolo velocità in bit/s
    DIFF_TIME=$((NOW_S - PREV_TIME))
    if [ "$DIFF_TIME" -gt 0 ]; then
        THROUGHPUT=$(( (BYTES - PREV_BYTES) * 8 / DIFF_TIME ))
    else
        THROUGHPUT=0
    fi

    # Output formattato a colonne
    printf "%-10s | %-13s | %-5s | %s\n" "$NOW" "$BACKLOG" "$DROPS" "$THROUGHPUT"

    # Aggiornamento stato per il ciclo successivo
    PREV_BYTES=$BYTES
    PREV_TIME=$NOW_S

    sleep $INTERVAL
done