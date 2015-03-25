/**
 * Implementation for Blink application.  Toggle the red LED when a
 * Timer fires.
 **/

module SensorFireC
{
  uses
  {    
    interface Boot;
    
    interface Receive;
    interface AMSend;    
    interface SplitControl as AMControl;
    interface Packet;
  }
}
implementation
{
  event void Boot.booted()
  {
    // onde vamos por o que o mote faz

    /* qdo inicia vais ter diferentes
    comportamentos depedendo do tipo de
    mote */
    dbg("Boot", "Application booted.\n");
  }

  event void AMControl.startDone(error_t err) 
  {}

  event void AMControl.stopDone(error_t err) 
  {}

  event void AMSend.sendDone(message_t* bufPtr, error_t error) 
  {}

  event message_t* Receive.receive(message_t* bufPtr, 
           void* payload, uint8_t len) 
  {return bufPtr;}
}

