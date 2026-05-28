#!/bin/sh

#Configuracio R6

# Instal·lar eines de xarxa
echo "Instal.lant eines..."
apk add iproute2

# Esperar a que Docker acabi de configurar-se
sleep 2

# Configurar per forwarding i maneig de trafic correctes
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.core.somaxconn=1024

PROVEIDORS="hurricane0 orangejazztel0 espanix0 google0 google1 netflix0 netflix1 netflix2 meta0 meta1 meta2"
CLIENTS="correostelecom0 avateladz0 airenetworks0 orangesst0 avatelsst0 orangerjt0 masmovilrjt0 avatelals0 lyntia0"
INTERFACES="$PROVEIDORS $CLIENTS"

# Netetja configuracio interficies docker
for i in $INTERFACES; do
  ip addr flush dev $i
  ip link set $i up
done

# Configurar interficies

#Proveidors
ip addr add 10.0.1.1/30 dev hurricane0
ip addr add 10.0.2.1/30 dev orangejazztel0
ip addr add 10.0.3.1/30 dev espanix0
ip addr add 10.0.4.1/30 dev google0
ip addr add 10.1.4.1/30 dev google1
ip addr add 10.0.5.1/30 dev netflix0
ip addr add 10.1.5.1/30 dev netflix1
ip addr add 10.2.5.1/30 dev netflix2
ip addr add 10.0.6.1/30 dev meta0
ip addr add 10.1.6.1/30 dev meta1
ip addr add 10.2.6.1/30 dev meta2

#Clients

#OP01-ADZ
ip addr add 10.10.1.1/30 dev correostelecom0
ip addr add 10.10.2.1/30 dev avateladz0

#OP02-INF
ip addr add 10.20.1.1/30 dev correostelecom0
ip addr add 10.20.2.1/30 dev airenetworks0

#OP03-SST
ip addr add 10.30.1.1/30 dev orangesst0
ip addr add 10.30.2.1/30 dev avatelsst0

#OP04-RJT
ip addr add 10.40.1.1/30 dev orangerjt0
ip addr add 10.40.2.1/30 dev masmovilrjt0

#OP05-ALS
ip addr add 10.50.1.1/30 dev avatelals0
ip addr add 10.50.2.1/30 dev airenetworks0

#OP06-EAM
ip addr add 10.60.1.1/30 dev lyntia0

#OP07-CST
ip addr add 10.70.1.1/30 dev lyntia0

#OP08-MDN
ip addr add 10.80.1.1/30 dev lyntia0

#OP09-JFG
ip addr add 10.90.1.1/30 dev lyntia0

#Encaminament estatic clients
for n in $(seq 1 5); do
  ip route add "1${n}0.${n}0.1.0/24" via "10.${n}0.2.2" metric 1
  ip route add "1${n}0.${n}0.0.0/23" via "10.${n}0.1.2" metric 1
  ip route add "1${n}0.${n}0.0.0/23" via "10.${n}0.2.2" metric 2
done
for n in $(seq 6 9); do
  ip route add "1${n}0.${n}0.0.0/23" via "10.${n}0.1.2"
done

# =========================
# EMULACIÓ DE CAPACITAT
# =========================
apply_qos() {
    # $1=interface, $2=rate, $3=delay
    tc qdisc add dev $1 root handle 1: tbf rate $2 burst 1mb latency 50ms
    if [ ! -z "$3" ]; then
		tc qdisc add dev $1 parent 1: handle 2: netem delay $3
    fi
}

apply_qos "hurricane0"      "10mbit" "2.02ms"
apply_qos "orangejazztel0"  "10mbit" "1.01ms"
apply_qos "espanix0"        "10mbit" "0.55ms"
apply_qos "google0"         "10mbit" "0.11ms"
apply_qos "google1"         "10mbit" "0.12ms"
apply_qos "netflix0"        "10mbit" "0.11ms"
apply_qos "netflix1"        "10mbit" "0.12ms"
apply_qos "netflix2"        "10mbit" "0.13ms"
apply_qos "meta0"           "10mbit" "0.11ms"
apply_qos "meta1"           "10mbit" "0.12ms"
apply_qos "meta2"           "10mbit" "0.13ms"

apply_qos "correostelecom0" "10mbit" "9.20ms"
apply_qos "avateladz0"      "10mbit" "5.89ms"
apply_qos "airenetworks0"   "10mbit" "10.07ms"
apply_qos "orangesst0"      "10mbit" "14.64ms"
apply_qos "avatelsst0"      "10mbit" "6.68ms"
apply_qos "orangerjt0"      "10mbit" "9.23ms"
apply_qos "masmovilrjt0"    "10mbit" "13.57ms"
apply_qos "avatelals0"      "10mbit" "12.70ms"
apply_qos "lyntia0"         "10mbit" "7.04ms"


echo "Esperant..."
sleep 5

# Inicialitzar FRR
/usr/lib/frr/docker-start

# Mantenir contenidor viu
sleep infinity