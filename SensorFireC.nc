/**
 * Implementation for Blink application.  Toggle the red LED when a
 * Timer fires.
 **/
module SensorFireC
{
  uses
  {    
    interface Boot;
    
    interface Packet;
    interface AMPacket;
    interface AMSend;
    interface SplitControl as AMControl;

    interface Receive;
  }
}
implementation
{
  bool busyRadio = FALSE;
  message_t messageRadio;
  SensorBroadCastMessage* msgSend;

  event void Boot.booted()
  {
    /* qdo inicia vais ter diferentes
    comportamentos depedendo do tipo de
    mote */
    // Inicializa o modulo de comunicação
    call AMControl.start();

    // onde vamos por o que o mote qdo inicia
    if(!TOS_NODE_ID){ // server node
      dbg("Boot", "I'am a server node - %d\n", TOS_NODE_ID);
    } else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ // routing nodes
      dbg("Boot", "I'am a routing node - %d\n", TOS_NODE_ID);
    } else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ // sensor nodes
      dbg("Boot", "I'am a sensor node - %d\n", TOS_NODE_ID);
      // 1º - Tenho que fazer o flooding para ver que routing nodes respondem
      // 2º - Caso receba ACK de mais que um -> escolher 1 e definir como meu routing node
      // 3º - Enviar msg para meu routing node c/ as minha infos(gps coords) q entregará ao server
    } else {
      dbg("Boot", "I don't know what I am [ERROR] - %d\n", TOS_NODE_ID);
    }
  }

  event void AMControl.startDone(error_t err) 
  {
    dbg("ActiveMessageC", "(ActiveMessageC) Inicialização do modulo de Comunicação\n");
    if (err != SUCCESS) {
      dbg("ActiveMessageC", "(ActiveMessageC) Erro na inicialização\n");
      call AMControl.start();
    } else {
      dbg("ActiveMessageC", "(ActiveMessageC) Inicialização Correta - Vamos mandar msg caso sejamos o sensor node\n");
      if(!TOS_NODE_ID){ // server node
      } else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ // routing nodes
      } else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ // sensor nodes
        dbg("ActiveMessageC", "(ActiveMessageC) Sensor node #%d - Fazer o broadcast para descobrir o routing node\n", TOS_NODE_ID);
        if(!busyRadio){
          msgSend = (SensorBroadCastMessage*)(call Packet.getPayload(&messageRadio, sizeof(SensorBroadCastMessage)));
          msgSend->nodeid = TOS_NODE_ID;
          dbg("ActiveMessageC", "(ActiveMessageC) Estou dentro do envio\n");
          if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorBroadCastMessage)) == SUCCESS) {
            dbg("ActiveMessageC", "(ActiveMessageC) Dps do call ser um SUCCESS\n");
            busyRadio = TRUE;
          }
        }
      } else {}
    }
  }

  event void AMControl.stopDone(error_t err) 
  {}

  event void AMSend.sendDone(message_t* bufPtr, error_t error) 
  {
    // Precisamos de dizer q o message buffer pode ser reutilizado
    dbg("ActiveMessageC", "(AMSendC) Enviei a msg\n");
    if (&messageRadio == bufPtr) {
      dbg("ActiveMessageC", "(AMSendC) Estou dentro do if\n");
      busyRadio = FALSE;
    }
  }

  event message_t* Receive.receive(message_t* bufPtr, 
           void* payload, uint8_t len) 
  {
    dbg("ActiveMessageC;", "(Receive) Chego Aqui1");
    if(!TOS_NODE_ID){ // server node
      if(len == sizeof(SensorBroadCastMessage)){ // Recebeu uma msg do sensor node
        SensorBroadCastMessage* msgReceive = (SensorBroadCastMessage*)payload;
        dbg("ActiveMessageC;", "(Receive) I'am the root(%d) and I receive a msg from sensor node #%d\n", TOS_NODE_ID, msgReceive->nodeid);       
      }
    } else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ // routing nodes
    } else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ // sensor nodes
    } else {
    }
    return bufPtr;
  }
}

