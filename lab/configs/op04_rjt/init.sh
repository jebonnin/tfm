#!/bin/sh

#Configuracio OP04-RJT

# Instal·lar eines de xarxa
echo "Instal.lant eines..."
apk add iproute2 iperf3

echo "Configurant orange0..."
ip addr flush dev orange0
ip addr add 10.40.1.2/30 dev orange0
ip link set orange0 up

echo "Configurant masmovil0..."
ip addr flush dev masmovil0
ip addr add 10.40.2.2/30 dev masmovil0
ip link set masmovil0 up

echo "Configurant loopback..."
ip addr add 140.40.0.40/32 dev lo
ip addr add 140.40.1.40/32 dev lo
ip link set lo up

echo "Configurant PBR (Policy Based Routing)..."
ip route add default via 10.40.1.1 dev orange0 table 100
ip route add default via 10.40.2.1 dev masmovil0 table 200

ip rule add from 140.40.0.40 table 100
ip rule add from 140.40.1.40 table 200

ip route add default via 10.40.1.1 metric 100
ip route add default via 10.40.2.1 metric 200

echo "Tot correcte."
sleep infinity