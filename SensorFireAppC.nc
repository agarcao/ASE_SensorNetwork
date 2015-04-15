/**
 * Blink is a basic application that toggles a mote's LED periodically.
 * It does so by starting a Timer that fires every second. It uses the
 * OSKI TimerMilli service to achieve this goal.
 *
 * @author andre_garcao@tecnico.ulisboa.pt
 **/

 #include "SensorFireLib.h"

configuration SensorFireAppC
{
}
implementation
{
  components SensorFireC, MainC;
  components ActiveMessageC;

  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG); 
  //components LogRead; 
  //components LogWrite; 
  

  SensorFireC.Boot -> MainC.Boot;

  SensorFireC.Receive -> AMReceiverC;
  SensorFireC.AMSend -> AMSenderC;
  SensorFireC.AMControl -> ActiveMessageC;
  SensorFireC.Packet -> AMSenderC;
}

