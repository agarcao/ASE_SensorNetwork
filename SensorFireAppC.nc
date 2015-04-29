/**
 * Blink is a basic application that toggles a mote's LED periodically.
 * It does so by starting a Timer that fires every second. It uses the
 * OSKI TimerMilli service to achieve this goal.
 *
 * @author andre_garcao@tecnico.ulisboa.pt
 **/

#include <stdio.h>
#include "Timer.h"
#include "SensorFireLib.h"

configuration SensorFireAppC
{
}
implementation
{
  components MainC;
  components SensorFireC;
  components ActiveMessageC;


  // For Local Time
  components LocalTimeMilliC; 

  // Mote comunication
  components new AMSenderC(AM_RADIO_SENSOR_FIRE_MSG);
  components new AMReceiverC(AM_RADIO_SENSOR_FIRE_MSG); 

  // Sensor
  components new DemoSensorC() as Sensor;

  //Timer
  components new TimerMilliC();

  components new QueueC(struct SensorFireMsg, 20) as Queue;
  

  SensorFireC.Boot -> MainC.Boot;
  
  
  SensorFireC.AMSend -> AMSenderC;
  SensorFireC.Packet -> AMSenderC;
  SensorFireC.AMPacket -> AMSenderC;
  SensorFireC.AMControl -> ActiveMessageC;

  SensorFireC.Receive -> AMReceiverC;

  SensorFireC.Read -> Sensor;

  SensorFireC.Timer -> TimerMilliC;

  SensorFireC.SendQueue -> Queue;

  SensorFireC.LocalTime -> LocalTimeMilliC;;
}

