#!/bin/sh

#Configuracio OP09-JFG

# Instal·lar eines de xarxa
echo "Instal.lant eines..."
apk add iproute2 iperf3

echo "Configurant lyntia0..."
ip addr flush dev lyntia0
ip addr add 10.90.1.2/30 dev lyntia0
ip link set lyntia0 up

echo "Configurant loopback..."
ip addr add 190.90.0.90/32 dev lo
ip link set lo up

echo "Configurant encaminament..."
ip route add "0.0.0.0/0" via 10.90.1.1 metric 1

echo "Tot correcte."
sleep infinity