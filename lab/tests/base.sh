#!/bin/bash

# ==============================================================================
# ENCAPSULACIÓ DE FUNCIONS LOCALS
# ==============================================================================
log() {
    echo -e "$1"
}

# Comandament directe per interactuar amb l'únic encaminador (R6)
R6_EXEC="docker exec lab-r6-1"

route_get_r6() {
    $R6_EXEC ip route get "$1"
}

# ==============================================================================
# LLINDARS DE VALIDACIÓ I CONFIGURACIÓ DE RENDIMENT
# ==============================================================================
MAX_ALLOWED_LOSS=1       # MÀXIM % de pèrdua de paquets tolerat
MAX_ALLOWED_JITTER=5.0   # MÀXIM Jitter tolerat en mil·lisegons
MAX_ALLOWED_RTT=20.0     # MÀXIM retard tolerat en mil·lisegons
MAX_PARALLEL_JOBS=5      # Control de concurrència per protegir la CPU del Host

# Variable global per fer el seguiment d'anomalies reals
ANOMALIES_DETECTADES=0

# =========================
# PROVEÏDORS
# =========================
TARGETS=(
  74.82.42.42
  80.58.61.250
  195.69.144.1
  8.8.8.8
  8.8.4.4
  52.94.76.1
  52.94.76.2
  52.94.76.3
  157.240.1.35
  157.240.1.36
  157.240.1.37
)

# =========================
# CLIENTS
# =========================
CLIENTS=(
  OP01-ADZ
  OP02-INF
  OP03-SST
  OP04-RJT
  OP05-ALS
  OP06-EAM
  OP07-CST
  OP08-MDN
  OP09-JFG
)

TMP_DIR="./tests/resultats/tmp"
mkdir -p "$TMP_DIR"
rm -f "$TMP_DIR"/*

# =========================
# 1) ENCAMINAMENT (TAULA RESUM)
# =========================
log "---- CAMINS ACTIUS A R6 (ESTAT INICIAL) ----\n"

# Capçalera de la taula
printf "%-15s | %-16s | %-15s\n" "DESTÍ TARGET" "INTERFÍCIE (dev)" "NEXT HOP (via)"
printf "%s\n" "--------------------------------------------------------"

for ip in "${TARGETS[@]}"; do
  # Executem el comando i capturem la sortida en una sola línia
  ROUTE_OUT=$(route_get_r6 "$ip" | tr '\n' ' ')

  # Extreure la interfície (dev) de forma segura
  DEV=$(echo "$ROUTE_OUT" | awk '{
    for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)
  }')

  # Extreure el Next Hop (via). Si és connexió directa, posarem "Directe"
  VIA=$(echo "$ROUTE_OUT" | awk '{
    found=0;
    for(i=1;i<=NF;i++) if($i=="via") { print $(i+1); found=1; break; }
    if(found==0) print "Directe"
  }')

  # Imprimir la fila de la taula completament alineada
  printf "%-15s | %-16s | %-15s\n" "$ip" "$DEV" "$VIA"
done

echo "" # Espai en blanc al final del bloc

# =========================
# 2) TRÀFIC
# =========================
log "---- TRÀFIC INTERFÍCIES R6 ----"
$R6_EXEC ./monitor.sh once reiniciar

# =========================
# 3) EXECUCIÓ DE TESTS (FASE EN PARAL·LEL CONTROLADA)
# =========================
log "---- EXECUTANT RÀFEGUES DE PING AMB CONTROL DE CONCURRÈNCIA ----"

for client in "${CLIENTS[@]}"; do
  N_CLIENT=$(echo "$client" | grep -oE '[0-9]+' | sed 's/^0//')
  IP_ORIGEN_A="1${N_CLIENT}0.${N_CLIENT}0.0.${N_CLIENT}0"
  IP_ORIGEN_B="1${N_CLIENT}0.${N_CLIENT}0.1.${N_CLIENT}0"

  for ip in "${TARGETS[@]}"; do
    PING_FILE_A="$TMP_DIR/ping_${client}_${ip}_A"
    PING_FILE_B="$TMP_DIR/ping_${client}_${ip}_B"

    # Control del Thread Pool per als Pings
    while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL_JOBS ]; do
       sleep 0.02
    done

    if [ "$N_CLIENT" -ge 6 ]; then
      # OP06 a OP09 només executen el test de la línia A
      (
        docker exec lab-"$client"-1 ping -I "$IP_ORIGEN_A" -c 20 -i 0.5 -W 1 "$ip" > "$PING_FILE_A" 2>&1
      ) &
    else
      # Operadors 1 a 5 executen ambdues rutes (A i B)
      (
        docker exec lab-"$client"-1 ping -I "$IP_ORIGEN_A" -c 20 -i 0.5 -W 1 "$ip" > "$PING_FILE_A" 2>&1
        docker exec lab-"$client"-1 ping -I "$IP_ORIGEN_B" -c 20 -i 0.5 -W 1 "$ip" > "$PING_FILE_B" 2>&1
      ) &
    fi
  done
done
wait # Esperem que finalitzin absolutament tots els pings

log "---- EXECUTANT TRACEROUTES SEQUENCIALS PER EVITAR COLLAPSE ----"
for client in "${CLIENTS[@]}"; do
  N_CLIENT=$(echo "$client" | grep -oE '[0-9]+' | sed 's/^0//')
  IP_ORIGEN_A="1${N_CLIENT}0.${N_CLIENT}0.0.${N_CLIENT}0"
  IP_ORIGEN_B="1${N_CLIENT}0.${N_CLIENT}0.1.${N_CLIENT}0"

  for ip in "${TARGETS[@]}"; do
    TRACE_FILE="$TMP_DIR/trace_${client}_${ip}"
    
    {
      echo "Traceroute via $IP_ORIGEN_A:"
      docker exec lab-"$client"-1 traceroute -q 1 -n -w 1 -m 5 -s "$IP_ORIGEN_A" "$ip" | awk '{print "  " $0}'
      
      # Només es llança el traceroute B si l'operador és inferior a OP06
      if [ "$N_CLIENT" -lt 6 ]; then
        echo "Traceroute via $IP_ORIGEN_B:"
        docker exec lab-"$client"-1 traceroute -q 1 -n -w 1 -m 5 -s "$IP_ORIGEN_B" "$ip" | awk '{print "  " $0}'
      fi
    } > "$TRACE_FILE" 2>&1
  done
done

# =========================
# 4) PROCESSAT I MOSTRA DE RESULTATS
# =========================
log "---- PROCESSANT INTERNAMENT ELS ASSATJOS I VALIDANT LIMITS ----"

for client in "${CLIENTS[@]}"; do
  N_CLIENT=$(echo "$client" | grep -oE '[0-9]+' | sed 's/^0//')
  IP_ORIGEN_A="1${N_CLIENT}0.${N_CLIENT}0.0.${N_CLIENT}0"
  IP_ORIGEN_B="1${N_CLIENT}0.${N_CLIENT}0.1.${N_CLIENT}0"

  for ip in "${TARGETS[@]}"; do
    
    # Decidim quins sufixos de línia processar segons el client
    SUFIXOS=("A" "B")
    if [ "$N_CLIENT" -ge 6 ]; then
      SUFIXOS=("A")
    fi

    for P_SUF in "${SUFIXOS[@]}"; do
      FILE="$TMP_DIR/ping_${client}_${ip}_${P_SUF}"
      IP_ORI=$([ "$P_SUF" == "A" ] && echo "$IP_ORIGEN_A" || echo "$IP_ORIGEN_B")
      
      if [ ! -f "$FILE" ]; then continue; fi

      OUT=$(cat "$FILE")
      LOSS=$(echo "$OUT" | grep -oE '[0-9]+% packet loss' | cut -d% -f1)
      RTTS=$(echo "$OUT" | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')

      if [ -z "$RTTS" ] || [ "$LOSS" -eq 100 ]; then
          continue
      fi
      
	  STATS=$(echo "$RTTS" | awk '
        BEGIN { count_raw=0; valid_count=0; }
        {
          count_raw++;
          # 1) DESCARTAR ELS DOS PRIMERS PINGS
          if (count_raw > 2) {
            rtts[valid_count] = $1;
            valid_count++;
          }
        }
        END {
          if (valid_count == 0) {
            printf "0.00|0.00|0.00|0.00";
            exit;
          }
          
          # Ordenar el vector de RTTs per calcular els quartils (mètode de la bafarada)
          for (i = 0; i < valid_count - 1; i++) {
            for (j = i + 1; j < valid_count; j++) {
              if (rtts[i] > rtts[j]) {
                tmp = rtts[i];
                rtts[i] = rtts[j];
                rtts[j] = tmp;
              }
            }
          }
          
          # Calcular Quartils per trobar els Outliers (IQR)
          q1_idx = int(valid_count * 0.25);
          q3_idx = int(valid_count * 0.75);
          q1 = rtts[q1_idx];
          q3 = rtts[q3_idx];
          iqr = q3 - q1;
          
          # Definim el límit superior per considerar un valor "outlier"
          # El límit inferior no cal avaluar-lo estant a prop de zero (min de xarxa)
          max_lim = q3 + (1.5 * iqr);
          
          # 2) FILTRATGE FINAL I CÀLCUL DE METRIQUES SENSE OUTLIERS
          sum = 0; final_count = 0; prev = 0; diff_sum = 0;
          min = 999999; max = 0;
          
          for (i = 0; i < valid_count; i++) {
            val = rtts[i];
            # Només processem si està dins dels valors normals i no és un pic de CPU
            if (val <= max_lim) {
              sum += val;
              if (val < min) min = val;
              if (val > max) max = val;
              
              if (final_count > 0) {
                diff = val - prev;
                if (diff < 0) diff = -diff;
                diff_sum += diff;
              }
              prev = val;
              final_count++;
            }
          }
          
          if (final_count == 0) {
            printf "0.00|0.00|0.00|0.00";
          } else {
            avg = sum / final_count;
            jitter = (final_count > 1) ? (diff_sum / (final_count - 1)) : 0.0;
            printf "%.2f|%.2f|%.2f|%.2f", min, avg, max, jitter;
          }
        }
      ')
	  
      AVG=$(echo "$STATS" | cut -d'|' -f2)
      JITTER=$(echo "$STATS" | cut -d'|' -f4)

      # VALIDACIÓ DE LLINDARS DE PÈRDUA
      if [ "$LOSS" -gt "$MAX_ALLOWED_LOSS" ]; then
          log "[ALERTA] Pèrdua excessiva detectada a $client cap a $ip via $IP_ORI ($LOSS%)"
          ANOMALIES_DETECTADES=$((ANOMALIES_DETECTADES + 1))
      fi

      # VALIDACIÓ DE RTT
      AVG_INT=$(echo "$AVG" | awk '{print int($1 * 1000)}')
      MAX_RTT_INT=$(echo "$MAX_ALLOWED_RTT" | awk '{print int($1 * 1000)}')

      if [ "$AVG_INT" -gt "$MAX_RTT_INT" ]; then
          log "[ALERTA] RTT (Avg) inacceptable detectat a $client cap a $ip via $IP_ORI (${AVG}ms)"
          ANOMALIES_DETECTADES=$((ANOMALIES_DETECTADES + 1))
      fi

      # VALIDACIÓ DE JITTER
      JITTER_INT=$(echo "$JITTER" | awk '{print int($1 * 1000)}')
      MAX_JITTER_INT=$(echo "$MAX_ALLOWED_JITTER" | awk '{print int($1 * 1000)}')

      if [ "$JITTER_INT" -gt "$MAX_JITTER_INT" ]; then
          log "[ALERTA] Jitter inacceptable detectat a $client cap a $ip via $IP_ORI (${JITTER}ms)"
          ANOMALIES_DETECTADES=$((ANOMALIES_DETECTADES + 1))
      fi
    done
  done
done

# =========================
# 5) TAULA DE RESULTATS FINAL
# =========================
printf "\n%-12s | %-15s | %-5s | %5s%% | %10s | %10s | %10s | %10s\n" \
"CLIENT" "DESTI" "RUTA" "LOSS" "MIN" "AVG" "MAX" "JITTER"
printf "%s\n" "--------------------------------------------------------------------------------------------------------"

for client in "${CLIENTS[@]}"; do
  N_CLIENT=$(echo "$client" | grep -oE '[0-9]+' | sed 's/^0//')
  
  for ip in "${TARGETS[@]}"; do
    SUFIXOS=("A" "B")
    if [ "$N_CLIENT" -ge 6 ]; then
      SUFIXOS=("A")
    fi

    for P_SUF in "${SUFIXOS[@]}"; do
      FILE="$TMP_DIR/ping_${client}_${ip}_${P_SUF}"
      [ ! -f "$FILE" ] && continue
      
      OUT=$(cat "$FILE")
      LOSS=$(echo "$OUT" | grep -oE '[0-9]+% packet loss' | cut -d% -f1)
      RTTS=$(echo "$OUT" | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')
      
      if [ -z "$RTTS" ] || [ "$LOSS" -eq 100 ]; then
        printf "%-12s | %-15s | %-5s | %5s%% | %10s | %10s | %10s | %10s\n" \
          "$client" "$ip" "$P_SUF" "$LOSS" "TIMEOUT" "TIMEOUT" "TIMEOUT" "TIMEOUT"
        continue
      fi

      STATS=$(echo "$RTTS" | awk '
        BEGIN { sum=0; count=0; diff_sum=0; prev=0; min=999999; max=0; }
        {
          rtt = $1;
          sum += rtt;
          if (rtt < min) min = rtt;
          if (rtt > max) max = rtt;
          if (count > 0) {
            diff = rtt - prev;
            if (diff < 0) diff = -diff;
            diff_sum += diff;
          }
          prev = rtt;
          count++;
        }
        END {
          if (count == 0) { min=0; max=0; avg=0; jitter=0; }
          else {
            avg = sum / count;
            jitter = (count > 1) ? (diff_sum / (count - 1)) : 0.0;
          }
          printf "%.2f|%.2f|%.2f|%.2f", min, avg, max, jitter;
        }
      ')
      
      MIN=$(echo "$STATS" | cut -d'|' -f1)
      AVG=$(echo "$STATS" | cut -d'|' -f2)
      MAX=$(echo "$STATS" | cut -d'|' -f3)
      JITTER=$(echo "$STATS" | cut -d'|' -f4)
      
      printf "%-12s | %-15s | %-5s | %5s%% | %8sms | %8sms | %8sms | %8sms\n" \
        "$client" "$ip" "$P_SUF" "$LOSS" "$MIN" "$AVG" "$MAX" "$JITTER"
    done
  done
done

# ==============================================================================
# RETORN DEL CODI D'ESTAT
# ==============================================================================
if [ "$ANOMALIES_DETECTADES" -gt 0 ]; then
    log "\n[CONCLUSIÓ] El test ha finalitzat amb $ANOMALIES_DETECTADES anomalies de rendiment detectades a R6."
    exit 1
else
    log "\n[CONCLUSIÓ] Tots els tests de xarxa a R6 estan dins els paràmetres d'operació correctes."
    exit 0
fi