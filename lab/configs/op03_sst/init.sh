#!/bin/sh

#Configuracio OP03-SST

# Instal·lar eines de xarxa
echo "Instal.lant eines..."
apk add iproute2 iperf3

echo "Configurant orange0..."
ip addr flush dev orange0
ip addr add 10.30.1.2/30 dev orange0
ip link set orange0 up

echo "Configurant avatel0..."
ip addr flush dev avatel0
ip addr add 10.30.2.2/30 dev avatel0
ip link set avatel0 up

echo "Configurant loopback..."
ip addr add 130.30.0.30/32 dev lo
ip addr add 130.30.1.30/32 dev lo
ip link set lo up

echo "Configurant PBR (Policy Based Routing)..."
ip route add default via 10.30.1.1 dev orange0 table 100
ip route add default via 10.30.2.1 dev avatel0 table 200

ip rule add from 130.30.0.30 table 100
ip rule add from 130.30.1.30 table 200

ip route add default via 10.30.1.1 metric 100
ip route add default via 10.30.2.1 metric 200

echo "Tot correcte."
sleep infinity