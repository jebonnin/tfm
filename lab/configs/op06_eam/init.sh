#!/bin/sh

#Configuracio OP06-EAM

# Instal·lar eines de xarxa
echo "Instal.lant eines..."
apk add iproute2 iperf3

echo "Configurant lyntia0..."
ip addr flush dev lyntia0
ip addr add 10.60.1.2/30 dev lyntia0
ip link set lyntia0 up

echo "Configurant loopback..."
ip addr add 160.60.0.60/32 dev lo
ip addr add 160.60.1.60/32 dev lo
ip link set lo up

echo "Configurant PBR (Policy Based Routing)..."
ip route add default via 10.60.1.1 dev lyntia0 table 100
ip route add default via 10.60.2.1 dev movistar0 table 200

ip rule add from 160.60.0.60 table 100
ip rule add from 160.60.1.60 table 200

ip route add default via 10.60.1.1 metric 100
ip route add default via 10.60.2.1 metric 200

echo "Tot correcte."
sleep infinity