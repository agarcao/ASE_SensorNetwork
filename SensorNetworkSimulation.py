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
import sys

t = Tossim([])
r = t.radio()
f = open("input.txt", "r")

# Aqui lemos o file e criamos as ligacoes entre motes
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

# Aqui lemos o file e criamos o modelo de Noise nas comunicacoes via radio
noise = open("MoteNoise.txt", "r")
lines = noise.readlines()
for line in lines:
  str = line.strip()
  if (str != ""):
    val = int(str)
    t.getNode(0).addNoiseTraceReading(val)
    t.getNode(100).addNoiseTraceReading(val)
    t.getNode(101).addNoiseTraceReading(val)
    t.getNode(102).addNoiseTraceReading(val)

t.getNode(0).createNoiseModel()
t.getNode(100).createNoiseModel()
t.getNode(101).createNoiseModel()
t.getNode(102).createNoiseModel()

t.addChannel("Boot", sys.stdout);
t.addChannel("AMReceiverC", sys.stdout);
t.addChannel("Receive", sys.stdout);
t.addChannel("AMSendC", sys.stdout);
t.addChannel("ActiveMessageC", sys.stdout);
m1 = t.getNode(0);
m2 = t.getNode(100);
m3 = t.getNode(101);
m4 = t.getNode(102);
m1.bootAtTime(0);
m2.bootAtTime(10);
m3.bootAtTime(15);
m4.bootAtTime(15);
