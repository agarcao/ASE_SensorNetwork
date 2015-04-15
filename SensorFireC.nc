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
  typedef enum {
    TYPE_SERVER,
    TYPE_ROUTING,
    TYPE_SENSOR
  } nodetype_t;
  
  nodetype_t nodetype;
  
  event void Boot.booted()
  {
    // onde vamos por o que o mote faz

    /* qdo inicia vais ter diferentes
    comportamentos depedendo do tipo de
    mote */
    char mess[] = {"Application booted.\n"};
    dbg("Boot", mess);
    
    if (TOS_NODE_ID == 0)       nodetype = TYPE_SERVER;
    else if (TOS_NODE_ID <= 99) nodetype = TYPE_ROUTING;
    else                        nodetype = TYPE_SENSOR;
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

