#!/bin/sh

#Configuracio OP05-ALS

# Instal·lar eines de xarxa
echo "Instal.lant eines..."
apk add iproute2 iperf3

echo "Configurant avatel0..."
ip addr flush dev avatel0
ip addr add 10.50.1.2/30 dev avatel0
ip link set avatel0 up

echo "Configurant airenetworks0..."
ip addr flush dev airenetworks0
ip addr add 10.50.2.2/30 dev airenetworks0
ip link set airenetworks0 up

echo "Configurant loopback..."
ip addr add 150.50.0.50/32 dev lo
ip addr add 150.50.1.50/32 dev lo
ip link set lo up

echo "Configurant PBR (Policy Based Routing)..."
ip route add default via 10.50.1.1 dev avatel0 table 100
ip route add default via 10.50.2.1 dev airenetworks0 table 200

ip rule add from 150.50.0.50 table 100
ip rule add from 150.50.1.50 table 200

ip route add default via 10.50.1.1 metric 100
ip route add default via 10.50.2.1 metric 200

echo "Tot correcte."
sleep infinity