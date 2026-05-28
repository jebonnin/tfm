#!/bin/sh

#Configuracio Meta

# Instal·lar eines de xarxa
echo "Instal.lant eines..."
apk add iproute2 iperf3

# Configurar interficies
echo "Configurant eth0..."
ip addr flush dev eth0
ip addr add 10.0.6.2/30 dev eth0
ip link set eth0 up

echo "Configurant eth1..."
ip addr flush dev eth1
ip addr add 10.1.6.2/30 dev eth1
ip link set eth1 up

echo "Configurant eth2..."
ip addr flush dev eth2
ip addr add 10.2.6.2/30 dev eth2
ip link set eth2 up

echo "Configurant loopback..."
PUBLIQUES="157.240.1.35/32 157.240.1.36/32 157.240.1.37/32"
for i in $PUBLIQUES; do
  ip addr add $i dev lo 
  #ip route add $i dev lo
done
ip link set lo up


# margen para evitar restart de watchfrr
echo "Esperant..."
sleep 5

# Inicialitzar FRR
echo "Inicialitzant FRR..."
/usr/lib/frr/docker-start &

# Esperar FRR
until vtysh -c "show ip bgp summary" 2>/dev/null | grep -q "BGP router identifier"; do
  echo "Esperant FRR..."
  sleep 1
done
echo "FRR iniciat correctament."

# margen para evitar restart de watchfrr
echo "Esperant..."
sleep 20

#Escoltar tràfic
for ip_mask in $PUBLIQUES; do
  ip=$(echo $ip_mask | cut -d/ -f1)
  #Un port per cada operador client
  for port in $(seq 5201 5209); do
    echo "Iniciant iperf port $port..."
    iperf3 -s -p $port -D -B $ip
  done
done

echo "Tot correcte."
sleep infinity