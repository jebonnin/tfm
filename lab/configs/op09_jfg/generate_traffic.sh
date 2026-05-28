#!/bin/sh

# Paràmetre d'entrada
if [ -z "$1" ]; then
    echo "Ús: $0 <0-5|stop>"
    exit 1
fi

FASE=$1

################################################################################################
#  PERSONALITZAR PER A CADA OPERADOR
################################################################################################

OP=9

Trafic0=0
Trafic1=0
case $FASE in
    0) Trafic0=0.036      ;;
    1) Trafic0=0.0396     ;;
    2) Trafic0=0.04356    ;;
    3) Trafic0=0.047916   ;;
    4) Trafic0=0.0527076  ;;
    5) Trafic0=0.05797836 ;;
    *) echo "Error: Argument no vàlid. Introdueix un número del 0 al 5 o 'stop'." ; exit 1 ;;
esac
################################################################################################

# --- 1. ATURADA DE TRÀFIC ANTERIOR ---
echo "Aturant qualsevol generació de tràfic prèvia..."

PIDS_A_MATAR=$(pgrep -f "generate_traffic.sh" | grep -v "^$$")
if [ -n "$PIDS_A_MATAR" ]; then
    kill -9 $PIDS_A_MATAR 2>/dev/null
fi

pkill -f "iperf3" 2>/dev/null
sleep 1

# Si l'argument era 'stop', ja hem complert l'objectiu i sortim netament.
if [ "$FASE" = "stop" ]; then
    echo "Tràfic aturat correctament."
    exit 0
fi

# Repartició de tràfic (Proporcions)
Hurricane_proportion=0.2714
OrangeJazztel_proportion=0.1352
Espanix_proportion=0.1657
Google_proportion=0.1417
Netflix_proportion=0.1146
Meta_proportion=0.1609

# --- 2. CÀLCUL MATEMÀTIC AMB DECIMALS (Corregits els Typos) ---
Hurricane0=$(echo "scale=2; $Trafic0 * $Hurricane_proportion" | bc)
Hurricane1=$(echo "scale=2; $Trafic1 * $Hurricane_proportion" | bc)

# Corregit: OrangeJazztel_proportion
OrangeJazztel0=$(echo "scale=2; $Trafic0 * $OrangeJazztel_proportion" | bc)
OrangeJazztel1=$(echo "scale=2; $Trafic1 * $OrangeJazztel_proportion" | bc)

Espanix0=$(echo "scale=2; $Trafic0 * $Espanix_proportion" | bc)
Espanix1=$(echo "scale=2; $Trafic1 * $Espanix_proportion" | bc)

Google0=$(echo "scale=2; ($Trafic0 * $Google_proportion / 2)" | bc)
Google1=$(echo "scale=2; ($Trafic0 * $Google_proportion / 2)" | bc)
Google2=$(echo "scale=2; ($Trafic1 * $Google_proportion / 2)" | bc)
Google3=$(echo "scale=2; ($Trafic1 * $Google_proportion / 2)" | bc)

# Corregit: Trafic0 i Trafic1 (Abans deia Tric0)
Netflix0=$(echo "scale=2; ($Trafic0 * $Netflix_proportion / 3)" | bc)
Netflix1=$(echo "scale=2; ($Trafic0 * $Netflix_proportion / 3)" | bc)
Netflix2=$(echo "scale=2; ($Trafic0 * $Netflix_proportion / 3)" | bc)
Netflix3=$(echo "scale=2; ($Trafic1 * $Netflix_proportion / 3)" | bc)
Netflix4=$(echo "scale=2; ($Trafic1 * $Netflix_proportion / 3)" | bc)
Netflix5=$(echo "scale=2; ($Trafic1 * $Netflix_proportion / 3)" | bc)

Meta0=$(echo "scale=2; ($Trafic0 * $Meta_proportion / 3)" | bc)
Meta1=$(echo "scale=2; ($Trafic0 * $Meta_proportion / 3)" | bc)
Meta2=$(echo "scale=2; ($Trafic0 * $Meta_proportion / 3)" | bc)
Meta3=$(echo "scale=2; ($Trafic1 * $Meta_proportion / 3)" | bc)
Meta4=$(echo "scale=2; ($Trafic1 * $Meta_proportion / 3)" | bc)
Meta5=$(echo "scale=2; ($Trafic1 * $Meta_proportion / 3)" | bc)

# --- 3. FUNCIÓ BASE (Corregida la línia 92 per a Alpine /bin/sh) ---
generar_trafic() {
    local DEST=$1; local ORIGEN=$2; local PORT=$3; local BW=$4; local NOM=$5
    
    # Validació POSIX per a números decimals buits o zero
    if [ -z "$BW" ] || [ "$BW" = "0" ] || [ "$BW" = ".00" ]; then
        return 0
    fi

    echo "Iniciant flux constant cap a $NOM ($DEST) des de $ORIGEN a ${BW}M..."
    while true; do
        iperf3 -c "$DEST" -B "$ORIGEN" -p "$PORT" -u -R -b "${BW}mbit" -t 10 --logfile /dev/null
        sleep 1
    done &
}

# --- 4. EXECUTAR FLUXOS ---
PORT_DESTI=$((5200 + OP))
IP_ORIGEN_0="1${OP}0.${OP}0.0.${OP}0"
IP_ORIGEN_1="1${OP}0.${OP}0.1.${OP}0"

# Connexio 1
generar_trafic "74.82.42.42"   "$IP_ORIGEN_0" "$PORT_DESTI" "$Hurricane0"     "Hurricane 1"
generar_trafic "80.58.61.250"  "$IP_ORIGEN_0" "$PORT_DESTI" "$OrangeJazztel0" "Orange-Jazztel 1"
generar_trafic "195.69.144.1"  "$IP_ORIGEN_0" "$PORT_DESTI" "$Espanix0"        "Espanix 1"
generar_trafic "8.8.8.8"       "$IP_ORIGEN_0" "$PORT_DESTI" "$Google0"         "Google 1"
generar_trafic "8.8.4.4"       "$IP_ORIGEN_0" "$PORT_DESTI" "$Google1"         "Google 2"
generar_trafic "52.94.76.1"    "$IP_ORIGEN_0" "$PORT_DESTI" "$Netflix0"        "Netflix 1"
generar_trafic "52.94.76.2"    "$IP_ORIGEN_0" "$PORT_DESTI" "$Netflix1"        "Netflix 2"
generar_trafic "52.94.76.3"    "$IP_ORIGEN_0" "$PORT_DESTI" "$Netflix2"        "Netflix 3"
generar_trafic "157.240.1.35"  "$IP_ORIGEN_0" "$PORT_DESTI" "$Meta0"           "Meta 1"
generar_trafic "157.240.1.36"  "$IP_ORIGEN_0" "$PORT_DESTI" "$Meta1"           "Meta 2"
generar_trafic "157.240.1.37"  "$IP_ORIGEN_0" "$PORT_DESTI" "$Meta2"           "Meta 3"

# Connexio 2
generar_trafic "74.82.42.42"   "$IP_ORIGEN_1" "$PORT_DESTI" "$Hurricane1"     "Hurricane 2"
generar_trafic "80.58.61.250"  "$IP_ORIGEN_1" "$PORT_DESTI" "$OrangeJazztel1" "Orange-Jazztel 2"
generar_trafic "195.69.144.1"  "$IP_ORIGEN_1" "$PORT_DESTI" "$Espanix1"        "Espanix 2"
generar_trafic "8.8.8.8"       "$IP_ORIGEN_1" "$PORT_DESTI" "$Google2"         "Google 3"
generar_trafic "8.8.8.8"       "$IP_ORIGEN_1" "$PORT_DESTI" "$Google3"         "Google 4"
generar_trafic "52.94.76.1"    "$IP_ORIGEN_1" "$PORT_DESTI" "$Netflix3"        "Netflix 4"
generar_trafic "52.94.76.2"    "$IP_ORIGEN_1" "$PORT_DESTI" "$Netflix4"        "Netflix 5"
generar_trafic "52.94.76.3"    "$IP_ORIGEN_1" "$PORT_DESTI" "$Netflix5"        "Netflix 6"
generar_trafic "157.240.1.35"  "$IP_ORIGEN_1" "$PORT_DESTI" "$Meta3"           "Meta 4"
generar_trafic "157.240.1.36"  "$IP_ORIGEN_1" "$PORT_DESTI" "$Meta4"           "Meta 5"
generar_trafic "157.240.1.37"  "$IP_ORIGEN_1" "$PORT_DESTI" "$Meta5"           "Meta 6"