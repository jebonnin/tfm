#!/bin/bash

# Comprovar paràmetre d'entrada
if [ -z "$1" ]; then
    echo "Ús: $0 <0-5>"
    exit 1
fi

FASE=$1

# Llista de totes les interfícies que gestiona R6 per a fer neteja automàtica
INTERFACES_TOTALS=(
    "hurricane0" "orangejazztel0" "espanix0" "google0" "google1" "netflix0" "netflix1" "netflix2" "meta0" "meta1" "meta2"
    "correostelecom0" "avateladz0" "airenetworks0" "orangesst0" "avatelsst0" "orangerjt0" "masmovilrjt0" "avatelals0" "lyntia0"
)

apply_qos() {
    # Paràmetres: $1=interfície, $2=rate (BW), $3=delay
    local IFACE=$1
    local RATE=$2
    local DELAY=$3

    # 1. Validació de la interfície (Obligatòria)
    if [ -z "$IFACE" ]; then
        echo "[ERROR] apply_qos: S'ha d'especificar una interfície." >&2
        return 1
    fi

    # Comprovar si la interfície existeix al sistema
    if ! ip link show dev "$IFACE" >/dev/null 2>&1; then
        echo "[WARN] apply_qos: La interfície $IFACE no existeix al sistema." >&2
        return 0
    fi

    # 2. Assignació de valors per defecte si estan buits
    if [ -z "$RATE" ]; then
        RATE="10mbit"
    fi

    if [ -z "$DELAY" ]; then
        case "$IFACE" in
            "hurricane0")       DELAY="2.02ms" ;;
            "orangejazztel0")   DELAY="1.01ms" ;;
            "espanix0")         DELAY="0.55ms" ;;
            "google0"|"netflix0"|"meta0")   DELAY="0.11ms" ;;
            "google1"|"netflix1"|"meta1")   DELAY="0.12ms" ;;
            "netflix2"|"meta2") DELAY="0.13ms" ;;
            "correostelecom0")  DELAY="9.20ms" ;;
            "avateladz0")       DELAY="5.89ms" ;;
            "airenetworks0")    DELAY="10.07ms" ;;
            "orangesst0")       DELAY="14.64ms" ;;
            "avatelsst0")       DELAY="6.68ms" ;;
            "orangerjt0")       DELAY="9.23ms" ;;
            "masmovilrjt0")     DELAY="12.70ms" ;;
            "avatelals0")       DELAY="16.6ms" ;;
            "lyntia0")          DELAY="6.59ms" ;;
            *)
                # Si es una interfaz que no está en la lista, no aplica delay
                DELAY="" 
                ;;
        esac
    fi

    # 3. Neteja neta de regles prèvies per evitar conflictes
    tc qdisc del dev "$IFACE" root 2>/dev/null

    # 4. Aplicació del Model de QoS (Jerarquia de Qdiscs)
    if [ -n "$DELAY" ]; then
        echo "Aplicant QoS a $IFACE -> BW: $RATE | Delay: $DELAY (Assegurat automàtic)"
        
        # tbf es configura com a root (handle 1:)
        if ! tc qdisc add dev "$IFACE" root handle 1: tbf rate "$RATE" burst 1mb latency 50ms; then
            echo "[ERROR] No s'ha pogut aplicar TBF a $IFACE" >&2
            return 1
        fi
        
        # netem es connecta directament com a fill del tbf (parent 1:)
        if ! tc qdisc add dev "$IFACE" parent 1: handle 2: netem delay "$DELAY"; then
            echo "[ERROR] No s'ha pogut aplicar el Delay (netem) a $IFACE" >&2
            return 1
        fi
    else
        # Si no té ni s'ha trobat cap delay per defecte, només s'aplica l'ample de banda
        echo "Aplicant QoS a $IFACE -> BW: $RATE (Sense Delay)"
        if ! tc qdisc add dev "$IFACE" root handle 1: tbf rate "$RATE" burst 1mb latency 50ms; then
            echo "[ERROR] No s'ha pogut aplicar TBF a $IFACE" >&2
            return 1
        fi
    fi

    return 0
}

# --- DEFINICIÓ DE CAPACITATS (BW) SEGONS LA FASE ---
#ip link set dev "interficie" up
#ip link set dev "interficie" down
#apply_qos "interficie" "rate mbit"


if [ "$FASE" != "0" ] && [ "$FASE" != "1" ] && [ "$FASE" != "2" ] && [ "$FASE" != "3" ] && [ "$FASE" != "4" ] && [ "$FASE" != "5" ]; then
	echo "Error: Fase $FASE  no vàlida. Introdueix un número del 0 al 5 o 'stop'."
	exit 1
fi

if [ "$FASE" = "0" ] || [ "$FASE" = "1" ] || [ "$FASE" = "2" ] || [ "$FASE" = "3" ] || [ "$FASE" = "4" ] || [ "$FASE" = "5" ]; then
	echo "Retornant a l'estat inicial..."
	
	#Reset de qualsevol fase aplicada
	for i in "${INTERFACES_TOTALS[@]}"; do
		apply_qos "$i" "10mbit"
		ip link set dev "$i" up
	done
	
	echo "Aplicant millores de la Fase 0..."
	#Apliquem canvis d'aquesta fase
	apply_qos "hurricane0" "40mbit"
	apply_qos "orangejazztel0" "25mbit"
	apply_qos "espanix0" "20mbit"
	ip link set dev "netflix2" down
	ip link set dev "meta2" down
	
	apply_qos "orangesst0" "25mbit"
	apply_qos "avatelsst0" "25mbit"
	apply_qos "orangerjt0" "25mbit"
	apply_qos "masmovilrjt0" "25mbit"
	apply_qos "lyntia0" "40mbit"
fi 

if [ "$FASE" = "1" ] || [ "$FASE" = "2" ] || [ "$FASE" = "3" ] || [ "$FASE" = "4" ] || [ "$FASE" = "5" ]; then
	echo "Aplicant millores de la Fase 1..."
	apply_qos "espanix0" "100mbit"
	ip link set dev "meta2" up
fi

if [ "$FASE" = "2" ] || [ "$FASE" = "3" ] || [ "$FASE" = "4" ] || [ "$FASE" = "5" ]; then
	echo "Aplicant millores de la Fase 2..."
	apply_qos "orangejazztel0" "40mbit"
fi

if [ "$FASE" = "3" ] || [ "$FASE" = "4" ] || [ "$FASE" = "5" ]; then
	echo "Aplicant millores de la Fase 3..."
	apply_qos "google0" "100mbit"
	ip link set dev "google1" down
fi

if [ "$FASE" = "4" ] || [ "$FASE" = "5" ]; then
	echo "Aplicant millores de la Fase 4..."
	apply_qos "masmovilrjt0" "40mbit"
	apply_qos "airenetworks0" "25mbit"
fi

if [ "$FASE" = "5" ]; then
	echo "Aplicant millores de la Fase 5..."
	ip link set dev "netflix2" up
	apply_qos "orangejazztel0" "40mbit"
fi


echo "----------------------------------------------------------"
echo "Canvis de QoS aplicats correctament a R6."
echo "=========================================================="