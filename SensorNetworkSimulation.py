#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys

from TOSSIM import *
from SensorsMsg import *


t = Tossim([])
r = t.radio()
f = open("input.txt", "r")

# Lista de nos para bootar. Bute?!...
nodes = set();

# Aqui lemos o file e criamos as ligacoes entre motes
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    fromNode = int(s[0])
    toNode   = int(s[1])
    r.add(fromNode, toNode, float(s[2]))
    if fromNode not in nodes:
      nodes.add(fromNode);
    if toNode not in nodes:
      nodes.add(toNode);

print("\nCriamos as ligações da rede de sensores de acordo com o ficheiro 'input.txt'\n");

# Aqui lemos o file e criamos o modelo de Noise nas comunicacoes via radio
noise = open("MoteNoise.txt", "r")
lines = noise.readlines()
for line in lines:
  str = line.strip()
  if (str != ""):
    val = int(str)
    for node in nodes:
      t.getNode(node).addNoiseTraceReading(val)

for node in nodes:
  t.getNode(node).createNoiseModel()

print("Lemos e criamos os modelos de noise de acordo com o ficheiro 'MoteNoise.txt'\n");

t.addChannel("Boot", sys.stdout);
t.addChannel("AMReceiverC", sys.stdout);
t.addChannel("Receive", sys.stdout);
t.addChannel("AMSendC", sys.stdout);
t.addChannel("ActiveMessageC", sys.stdout);

# Bute agora bootar tudo o que é para ser bootado...
for node in nodes:
  # Lembro-me de o prof ter dito algures que os motes não podiam dar boot todos
  # ao mesmo tempo pk senão dá filósofos a comer esparguete...
  # Portanto vamos aleatório...
  bootTime = (node*7+7) % 99
  t.getNode(node).bootAtTime(bootTime);

while True:
  print("Digite a letra da opção desejada:\n");
  print("[A] Run Next Event");
  print("[B] Run Next 10 Events");
  print("[C] Run Next 100 Events");
  print("[D] Check nodes in network");
  print("[E] Simulate malfunction in Routing Node");
  print("[F] Simulate fire event");
  print("[G] Show log file");
  print("[H] Exit Simulation\n");
  c = sys.stdin.read(1);
  userinput = sys.stdin.readline();

  if c == 'A':
    t.runNextEvent();
  elif c == 'B':
    i = 0;
    for i in range(0, 9):
      t.runNextEvent();
      i += 1;
  elif c == 'C':
    i = 0;
    for i in range(0, 99):
      t.runNextEvent();
      i += 1;
  elif c == 'D':
    print("Nodes in Network:");
    for node in nodes:
      if node == 0:
        print("[Root Node] ID #"), node;
      elif node in range(1, 99):
        print("[Routing Node] ID #"), node;
      else:
        print("[Sensor Node] ID #"), node;
    sys.stdout.write("\n");
  elif c == 'E':
    print("Choose the Routing Node ID that will have the malfunction");
    for node in nodes:
      if node in range(1, 99):
        print("[Routing Node] ID #"), node;
    
    nodeId = sys.stdin.read(1);
    userinput = sys.stdin.readline();

    if nodeId in range(1, 99) and nodeId in nodes:
      t.getNode(nodeId).turnOff();  
    else:
      print("Node do not exist in this simulation or is not a Routing node");      
  elif c == 'F':
    print("Choose the Sensor Node ID that will receive the fire alert");
    for node in nodes:
      if node in range(100, 999):
        print("[Sensor Node] ID #"), node;

    nodeId = sys.stdin.read(1);
    userinput = sys.stdin.readline();

    if nodeId in range(100, 999) and nodeId in nodes:
      msg = SensorsMsg();
      msg.set_fire(1);
      msg.set_temperature(40);
      msg.set_humidity(40);
      pkt = t.newPacket();
      pkt.setData(msg.data)
      pkt.setType(msg.get_amType());
      pkt.setDestination(nodeId);
      pkt.deliver(nodeId, t.time() + 3)
    else:
      print("Node do not exist in this simulation or is not a Sensor node");    
  elif c == 'G':
    f = open('logFile.txt')
    for line in f:
      sys.stdout.write(line);
    f.close();
    sys.stdout.write("\n");
  elif c == 'H':
    sys.exit();
  else:
    print("Opção n é valida. Por favor digite letra válida");