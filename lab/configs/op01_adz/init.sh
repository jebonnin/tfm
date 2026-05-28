#!/bin/sh

#Configuracio OP01-ADZ

# Instal·lar eines de xarxa
echo "Instal.lant eines..."
apk add iproute2 iperf3

echo "Configurant correostelecom0..."
ip addr flush dev correostelecom0
ip addr add 10.10.1.2/30 dev correostelecom0
ip link set correostelecom0 up

echo "Configurant avatel0..."
ip addr flush dev avatel0
ip addr add 10.10.2.2/30 dev avatel0
ip link set avatel0 up

echo "Configurant loopback..."
ip addr add 110.10.0.10/32 dev lo
ip addr add 110.10.1.10/32 dev lo
ip link set lo up

echo "Configurant PBR (Policy Based Routing)..."
ip route add default via 10.10.1.1 dev correostelecom0 table 100
ip route add default via 10.10.2.1 dev avatel0 table 200

ip rule add from 110.10.0.10 table 100
ip rule add from 110.10.1.10 table 200

ip route add default via 10.10.1.1 metric 100
ip route add default via 10.10.2.1 metric 200

echo "Tot correcte."
sleep infinity