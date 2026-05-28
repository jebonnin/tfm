#!/bin/sh

#Configuracio OP02-INF

# Instal·lar eines de xarxa
echo "Instal.lant eines..."
apk add iproute2 iperf3

echo "Configurant correostelecom0..."
ip addr flush dev correostelecom0
ip addr add 10.20.1.2/30 dev correostelecom0
ip link set correostelecom0 up

echo "Configurant airenetworks0..."
ip addr flush dev airenetworks0
ip addr add 10.20.2.2/30 dev airenetworks0
ip link set airenetworks0 up

echo "Configurant loopback..."
ip addr add 120.20.0.20/32 dev lo
ip addr add 120.20.1.20/32 dev lo
ip link set lo up

echo "Configurant PBR (Policy Based Routing)..."
ip route add default via 10.20.1.1 dev correostelecom0 table 100
ip route add default via 10.20.2.1 dev airenetworks0 table 200

ip rule add from 120.20.0.20 table 100
ip rule add from 120.20.1.20 table 200

ip route add default via 10.20.1.1 metric 100
ip route add default via 10.20.2.1 metric 200

echo "Tot correcte."
sleep infinity