COMPONENT=SensorFireAppC

# O que se segue é necessário para injectar pacotes na rede.
BUILD_EXTRA_DEPS = SensorFireMsg.py
SensorFireMsg.py: SensorFireLib.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=SensorFireMsg SensorFireLib.h SensorBroadCastMessage -o $@

include $(MAKERULES)
