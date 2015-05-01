COMPONENT=SensorFireAppC

# O que se segue é necessário para injectar pacotes na rede.
CLEAN_EXTRA = DebugMessage.py DebugMessage.pyc
BUILD_EXTRA_DEPS = DebugMessage.py
DebugMessage.py: SensorFireLib.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=DebugMessage SensorFireLib.h DebugMessage -o $@

include $(MAKERULES)
