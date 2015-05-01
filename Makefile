COMPONENT=SensorFireAppC
BUILD_EXTRA_DEPS = SensorsMsg.py
CLEAN_EXTRA = SensorsMsg.py

SensorsMsg.py: SensorFireLib.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=SensorsMsg SensorFireLib.h sensors_msg -o $@

include $(MAKERULES)
