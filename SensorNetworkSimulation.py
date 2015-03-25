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

t.addChannel("Boot", sys.stdout)

# Aqui lemos o file e criamos o modelo de Noise nas comunicacoes via radio
noise = open("MoteNoise.txt", "r")
lines = noise.readlines()
for line in lines:
  str = line.strip()
  if (str != ""):
    val = int(str)
    for i in range(1, 4):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, 4):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()
'''