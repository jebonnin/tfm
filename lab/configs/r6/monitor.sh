#!/bin/sh

export LC_ALL=C

SERVERS="hurricane0 orangejazztel0 espanix0 google0 google1 netflix0 netflix1 netflix2 meta0 meta1 meta2"
CLIENTS="correostelecom0 avateladz0 airenetworks0 orangesst0 avatelsst0 orangerjt0 masmovilrjt0 avatelals0 lyntia0"
INTERFACES="$SERVERS $CLIENTS"

TMP="/tmp/netstats"

RUN_ONCE=0
INTERVAL=5   # segundos reales entre muestras

case "$1" in
  once|1|single) RUN_ONCE=1 ;;
  reiniciar) rm -rf "$TMP" ;;
esac

mkdir -p "$TMP"

get_capacity() {
    local INTERFACE=$1
    
    # 1. Consultamos el qdisc de la interfaz en R6
    # La salida de 'tc qdisc show' da algo como: "qdisc tbf 1: root refcnt 2 rate 10Mbit burst 1Mb..."
    local TC_OUTPUT=$(tc qdisc show dev "$INTERFACE" 2>/dev/null)
    
    # 2. Extraemos el valor del parámetro 'rate'
    local RATE=$(echo "$TC_OUTPUT" | awk '/rate/ {
        for(i=1; i<=NF; i++) {
            if($i=="rate") {
                print $(i+1)
            }
        }
    }')

    # 3. Procesamos la unidad que devuelva 'tc' (Mbit o Kbit) para estandarizar a Mbps
    case "$RATE" in
        *Mbit)
            echo "${RATE%Mbit}"
            ;;
        *Kbit)
            # Si está en Kbit, lo dividimos por 1024 usando bc
            local KBIT="${RATE%Kbit}"
            echo "$KBIT / 1024" | bc
            ;;
        *)
            # Si no hay reglas de tc aplicadas o da error, devolvemos el valor por defecto (10 Mbps)
            echo 10
            ;;
    esac
}

fmt() {
  printf "%.2f" "$1" | sed 's/\./,/g'
}

now_ms() {
  # milisegundos, rápido y suficiente precisión
  date +%s%3N
}

prime() {
  NOW=$(now_ms)
  for i in $INTERFACES; do
    IF="/sys/class/net/$i/statistics"
    [ ! -e "$IF/rx_bytes" ] && continue

    RX=$(cat "$IF/rx_bytes")
    TX=$(cat "$IF/tx_bytes")

    echo "$RX $NOW" > "$TMP/${i}_rx"
    echo "$TX $NOW" > "$TMP/${i}_tx"
  done
}

# =========================
# PRIMERA LECTURA
# =========================
prime
sleep "$INTERVAL"

while true; do

  echo "==== MONITOR (%) ===="
  printf "%-20s | %8s | %8s | %6s\n" "INTERFICIE" "RX" "TX" "%UTIL"
  echo "----------------------------------------------------------------"

  NOW=$(now_ms)

  S_RX=0; S_TX=0
  C_RX=0; C_TX=0

  for i in $INTERFACES; do
    IF="/sys/class/net/$i/statistics"
    [ ! -e "$IF/rx_bytes" ] && continue

    STATE=$(cat /sys/class/net/$i/operstate 2>/dev/null)

    RX_N=$(cat "$IF/rx_bytes")
    TX_N=$(cat "$IF/tx_bytes")

    RXF="$TMP/${i}_rx"
    TXF="$TMP/${i}_tx"

    read RX_P T_RX < "$RXF"
    read TX_P T_TX < "$TXF"

    DT_MS=$((NOW - T_RX))
    [ "$DT_MS" -le 0 ] && DT_MS=1

    # interfaz DOWN → no calcular
    if [ "$STATE" != "up" ]; then
      printf "%-20s | %8s | %8s | %6s\n" "$i" "-" "-" "DOWN"
      echo "$RX_N $NOW" > "$RXF"
      echo "$TX_N $NOW" > "$TXF"
      continue
    fi

    RX_DIFF=$((RX_N - RX_P))
    TX_DIFF=$((TX_N - TX_P))

    [ "$RX_DIFF" -lt 0 ] && RX_DIFF=0
    [ "$TX_DIFF" -lt 0 ] && TX_DIFF=0

    # Gbps real (sin escala)
    RX_G=$(awk -v d="$RX_DIFF" -v dt="$DT_MS" 'BEGIN {print (d*8)/(dt*1e6)}')
    TX_G=$(awk -v d="$TX_DIFF" -v dt="$DT_MS" 'BEGIN {print (d*8)/(dt*1e6)}')

    CAP=$(get_capacity "$i")

    UTIL=$(awk -v r="$RX_G" -v t="$TX_G" -v c="$CAP" '
      BEGIN {
        u = (r>t?r:t)/c*100;
        if (u>100) u=100;
        print u;
      }
    ')

    printf "%-20s | %8s | %8s | %6s%% [%sG]\n" \
      "$i" \
      "$(fmt "$RX_G")" \
      "$(fmt "$TX_G")" \
      "$(fmt "$UTIL")" \
	  "$CAP"

    case " $SERVERS " in
      *" $i "*)
        S_RX=$(awk "BEGIN{print $S_RX+$RX_G}")
        S_TX=$(awk "BEGIN{print $S_TX+$TX_G}")
      ;;
    esac

    case " $CLIENTS " in
      *" $i "*)
        C_RX=$(awk "BEGIN{print $C_RX+$RX_G}")
        C_TX=$(awk "BEGIN{print $C_TX+$TX_G}")
      ;;
    esac

    echo "$RX_N $NOW" > "$RXF"
    echo "$TX_N $NOW" > "$TXF"
  done

  echo "----------------------------------------------------------------"
  echo "==== TOTALS ===="
  printf "SERVIDORS -> RX: %8s Gbps | TX: %8s Gbps\n" "$(fmt "$S_RX")" "$(fmt "$S_TX")"
  printf "CLIENTS   -> RX: %8s Gbps | TX: %8s Gbps\n" "$(fmt "$C_RX")" "$(fmt "$C_TX")"
  echo "----------------------------------------------------------------"

  [ "$RUN_ONCE" -eq 1 ] && break

  sleep "$INTERVAL"
  clear
done