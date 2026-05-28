#!/bin/bash

# Llista de tots els clients (contenidors)
CLIENTS=("OP01-ADZ" "OP02-INF" "OP03-SST" "OP04-RJT" "OP05-ALS" "OP06-EAM" "OP07-CST" "OP08-MDN" "OP09-JFG")

# Mapeig de fallades: Quin proveïdor falla i quina interfície de R6 cal tombar per simular-ho
declare -A INTERFACES_FALLO
INTERFACES_FALLO["Normal"]="" 
INTERFACES_FALLO["Falla Hurricane"]="hurricane0"
INTERFACES_FALLO["Falla Orange-Jazztel"]="orangejazztel0"
INTERFACES_FALLO["Falla Espanix"]="espanix0"
INTERFACES_FALLO["Falla Google"]="google0 google1"
INTERFACES_FALLO["Falla Netflix"]="netflix0 netflix1 netflix2"
INTERFACES_FALLO["Falla Meta"]="meta0 meta1 meta2"
INTERFACES_FALLO["Falla Meta + Google"]="meta0 meta1 meta2 google0 google1"
INTERFACES_FALLO["Falla Meta + Netflix"]="meta0 meta1 meta2 netflix0 netflix1 netflix2"
INTERFACES_FALLO["Falla Meta + Espanix"]="meta0 meta1 meta2 espanix0"

# Ordre d'execució desitjat per als escenaris de proves
ESCENARIOS=(
    "Normal" "Falla Hurricane" "Falla Orange-Jazztel" "Falla Espanix" 
    "Falla Google" "Falla Netflix" "Falla Meta" 
    "Falla Meta + Google" "Falla Meta + Netflix" "Falla Meta + Espanix"
)

# Funció per donar format
format_time() {
    local SECONDS_INPUT=$1
    if [ "$SECONDS_INPUT" -ge 60 ]; then
        echo "$((SECONDS_INPUT / 60))m $((SECONDS_INPUT % 60))s"
    else
        echo "${SECONDS_INPUT}s"
    fi
}

echo "=========================================================="
echo "          INICIANT BATERIA COMPLETA DE TESTS               "
echo "=========================================================="

# Capturem el moment exacte de l'inici global de la simulació
GLOBAL_START=$(date +%s)

# --- LOG GLOBAL DE RESULTATS ---
mkdir -p tests/resultats/
LOG_RESULTADOS="tests/resultats/resultats_tests.log"
echo "Informe de Tests de Xarxa - $(date)" > "$LOG_RESULTADOS"
echo "----------------------------------------------------------" >> "$LOG_RESULTADOS"

# BUCLE PRINCIPAL: PER A CADA FASE (0 a 5)
for FASE in {0..5}; do
    echo -e "\n=========================================================="
    echo " >>> CONFIGURANT L'ENTORN PER A LA FASE: $FASE <<< "
    echo "=========================================================="
    echo "Fase $FASE:" >> "$LOG_RESULTADOS"
	
	 # Capturem el temps de l'inici de la Fase actual
    FASE_START=$(date +%s)
	
    # 1. Configurar interfícies de capacitat i QoS a R6 per a la fase actual (Inici de Fase)
    echo "[R6] Aplicant capacitats globals de la Fase $FASE..."
    docker exec lab-r6-1 /set_interfaces.sh "$FASE"
    sleep 2

    # 2. Aixecar i configurar la generació de tràfic a tots els clients
    for CLIENTE in "${CLIENTS[@]}"; do
        echo "[$CLIENTE] Configurant i llançant tràfic per a la Fase $FASE..."
        docker exec "lab-${CLIENTE}-1" /generate_traffic.sh "$FASE"
    done

    # Donar uns segons perquè els fluxos UDP d'iperf3 s'estabilitzin
    echo "Esperant 10 segons a que el tràfic de la xarxa s'estabilitzi..."
    sleep 10

    # 3. REALITZACIÓ DE PROVES I ESCENARIS DE FALLADES
    for ESCENARIO in "${ESCENARIOS[@]}"; do
        echo -e "\n----------------------------------------------------------"
        echo " Executant l'Escenari: $ESCENARIO (Fase $FASE)"
        echo "----------------------------------------------------------"
		
		# Capturem el temps que triga aquest esceari
		ESCENARI_START=$(date +%s)
		
        # INTERVENCIÓ: Provocar la fallada tombant les interfícies a R6
        IFACES_A_TIRAR=${INTERFACES_FALLO[$ESCENARIO]}
        if [ -n "$IFACES_A_TIRAR" ]; then
            for iface in $IFACES_A_TIRAR; do
                echo "[-] [SABOTATGE] Tombant la interfície $iface a R6..."
                docker exec lab-r6-1 ip link set dev "$iface" down
            done
            echo "Esperant la convergència de xarxa per Failover (15s)..."
            sleep 15 # Temps perquè l'encaminament busqui camins alternatius
        fi

        # EXECUCIÓ DEL TEST BASE
        echo "[Test] Executant proves de connectivitat, latència i ocupació..."
        mkdir -p "tests/resultats/fase_${FASE}"
        OUTPUT_TEST="tests/resultats/fase_${FASE}/test_${ESCENARIO// /_}.log"
        
        # Execució real de les proves cridant el teu script base.sh
        ./tests/base.sh > "$OUTPUT_TEST" 2>&1
        ESTADO_TEST=$?

        # VALIDACIÓ DEL TEST
        if [ $ESTADO_TEST -eq 0 ]; then
            echo "[OK] Escenari '$ESCENARIO' completat amb èxit."
            echo "  - $ESCENARIO: OK" >> "$LOG_RESULTADOS"
        else
            echo "[ERROR] L'escenari '$ESCENARIO' ha detectat anomalies (Veure detalls a $OUTPUT_TEST)."
            echo "  - $ESCENARIO: ERROR (Veure detalls a $OUTPUT_TEST)" >> "$LOG_RESULTADOS"
        fi

        # RESTAURACIÓ: Recuperar l'estat net i correcte de la prova en cada loop
        if [ -n "$IFACES_A_TIRAR" ]; then
            for iface in $IFACES_A_TIRAR; do
                echo "[+] [REPARACIÓ] Forçant aixecament de la interfície $iface a R6..."
                docker exec lab-r6-1 ip link set dev "$iface" up
            done
            
            # Petit marge indispensable perquè el kernel assimili l'estat operacional 'up'
            sleep 2 

            # REESTABLIMENT DE L'ENTORN CORRECTE (Aplicació de la teva idea)
            echo "[R6] Forçant re-aplicació de l'estat net i paràmetres de la Fase $FASE..."
            docker exec lab-r6-1 /set_interfaces.sh "$FASE" > /dev/null 2>&1
            
            # TEMPS CRÍTIC DE CONVERGÈNCIA (OSPF / BGP)
            # Temps necessari perquè els protocols realliberin les rutes en les rutes restaurades
            echo "Esperant la reconvergència de rutes post-restauració (15s)..."
            sleep 15
        fi
		
		ESCENARI_END=$(date +%s)
		ESCENARI_DIFF=$((ESCENARI_END - ESCENARI_START))
		echo "L'execució de l'escenari $ESCENARIO ha transcorregut en: $(format_time $ESCENARI_DIFF)"
    done

    # 4. PARADA DE TRÀFIC EN FINALITZAR LA FASE
    echo -e "\n[Neteja] Aturant el tràfic de la Fase $FASE a tots els clients..."
    for CLIENTE in "${CLIENTS[@]}"; do
        docker exec "lab-${CLIENTE}-1" /generate_traffic.sh stop > /dev/null 2>&1
    done
    
	
    # Càlcul del temps total consumit per tota la Fase completa
    FASE_END=$(date +%s)
    FASE_DIFF=$((FASE_END - FASE_START))
    
    echo "=========================================================="
    echo "Temps total d'aquesta FASE: $FASE: $(format_time $FASE_DIFF)"
    echo "=========================================================="
	
    echo "----------------------------------------------------------" >> "$LOG_RESULTADOS"
done

GLOBAL_END=$(date +%s)
GLOBAL_DIFF=$((GLOBAL_END - GLOBAL_START))

echo -e "\n=========================================================="
echo "   BATERIA DE TESTS FINALITZADA. COMPROVAR: $LOG_RESULTADOS"
echo ""
echo "TEMPS TOTAL SIMULACIÓ: $(format_time $GLOBAL_DIFF)"
echo "=========================================================="

