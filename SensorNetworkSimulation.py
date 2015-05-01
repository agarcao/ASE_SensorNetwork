#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
from TOSSIM import *
t = Tossim([])
m = t.getNode(32);
m.bootAtTime(45654);
import sys
t.addChannel("Boot", sys.stdout);
t.runNextEvent();
'''

from TOSSIM import *
from tinyos.tossim.TossimApp import *
import sys

n = NescApp()
t = Tossim(n.variables.variables())
r = t.radio()
f = open("input.txt", "r")

# Lista de nos para bootar. Bute?!...
toboot = set()

# Aqui lemos o file e criamos as ligacoes entre motes
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print " ", s[0], " ", s[1], " ", s[2];
    fromnode = int(s[0])
    tonode   = int(s[1])
    r.add(fromnode, tonode, float(s[2]))
    toboot.add(fromnode)
    toboot.add(tonode)

# Aqui lemos o file e criamos o modelo de Noise nas comunicacoes via radio
noise = open("MoteNoise.txt", "r")
lines = noise.readlines()
for line in lines:
  noisestr = line.strip()
  if (noisestr != ""):
    val = int(noisestr)
    for bute in toboot:
      t.getNode(bute).addNoiseTraceReading(val)

for bute in toboot:
  t.getNode(bute).createNoiseModel()

t.addChannel("Boot", sys.stdout);
t.addChannel("AMReceiverC", sys.stdout);
t.addChannel("Receive", sys.stdout);
t.addChannel("AMSendC", sys.stdout);
t.addChannel("ActiveMessageC", sys.stdout);

def m(n): return t.getNode(n)

# Bute agora bootar tudo o que é para ser bootado...
for bute in toboot:
  # Lembro-me de o prof ter dito algures que os motes não podiam dar boot todos
  # ao mesmo tempo pk senão dá filósofos a comer esparguete...
  # Portanto vamos aleatório...
  butime = (bute*7+7) % 99
  m(bute).bootAtTime(butime)
  print ("Nó %4d inicia aos %5d" % (bute,butime))


def do():
  print("At t.time()=="+str(t.time())+" event returns: " + str(t.runNextEvent()) + "!")
  #print "\n"
def doto(millisecs):
  while t.time() < millisecs:
    do()

def varval(varname):
  return m(0).getVariable("SensorFireC."+varname).getData()


from SensorFireMsg import *

def createInjectablePacket():
  return SensorFireMsg()
def injectIn(pkt, nodenr):
  pkt.deliver(nodenr, t.time())
