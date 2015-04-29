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

    interface Timer<TMilli>;

    interface Read<uint16_t>;
  }
}
implementation
{
  bool busyRadio = FALSE;
  message_t messageRadio;
  
  int msg_curr_seq = 0;

  SensorBroadCastMessage *msgSend, *msgReceive;

  nx_uint16_t currentTemperature;
  
  // Para o routing node evitar repetir pacotes
  // TODO: devia ser uma lista/vector.
  nx_uint32_t lastRouted;

  FILE *logFile;

  event void Boot.booted()
  {
    /* qdo inicia vais ter diferentes
    comportamentos depedendo do tipo de
    mote */    

    // onde vamos por o que o mote qdo inicia
    if(!TOS_NODE_ID){ // server node
      dbg("Boot", "(Boot) I'am a server node - %d\n", TOS_NODE_ID);
    } else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ // routing nodes
      // Enquanto que os sensor nodes têm que sabercom quem é que falam,
      //  os routing nodes podem simplesmente fazer sempre broadcast.
      lastRouted = 0;
      dbg("Boot", "(Boot) I'am a routing node - %d\n", TOS_NODE_ID);
    } else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ // sensor nodes
      dbg("Boot", "(Boot) I'am a sensor node - %d\n", TOS_NODE_ID);      
      // 1º - Tenho que fazer o flooding para ver que routing nodes respondem
      // 2º - Caso receba ACK de mais que um -> escolher 1 e definir como meu routing node
      // 3º - Enviar msg para meu routing node c/ as minha infos(gps coords) q entregará ao server
    } else {
      dbg("Boot", "(Boot) I don't know what I am [ERROR] - %d\n", TOS_NODE_ID);
    }

    // Inicializa o modulo de comunicação
    dbg("Boot", "(Boot) Initializa AMControl\n");      
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) 
  {
    dbg("ActiveMessageC", "(AMControl.startDone) Inicialização do modulo de Comunicação\n");
    if (err != SUCCESS) {
      
      dbg("ActiveMessageC", "(AMControl.startDone) Erro na inicialização\n");
      call AMControl.start();
    } else {

      dbg("ActiveMessageC", "(AMControl.startDone) Inicialização Correta\n");
      if(!TOS_NODE_ID){ // server node
        dbg("ActiveMessageC", "(AMControl.startDone) Server Node\n");
      } else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ // routing nodes
        dbg("ActiveMessageC", "(AMControl.startDone) Inicalizamos o timer para o router #%d \n", TOS_NODE_ID);
      } else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ // sensor nodes
        // Inializamos o timer
        dbg("ActiveMessageC", "(AMControl.startDone) Inicalizamos o timer para o nó #%d \n", TOS_NODE_ID);
        call Timer.startPeriodic(DEFAULT_INTERVAL);        
      } 
    }
  }

  event void AMControl.stopDone(error_t err) {
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) 
  {
    // Precisamos de dizer q o message buffer pode ser reutilizado
    if (&messageRadio == bufPtr) {
      currentTemperature = -1;
      busyRadio = FALSE;
    }
  }

  event message_t* Receive.receive(message_t* bufPtr, 
           void* payload, uint8_t len) 
  {
    dbg("AMReceiverC", "(Receive) Recebi msg\n");
    msgReceive = (SensorBroadCastMessage*) payload;
    
    if(!TOS_NODE_ID){ // server node
      dbg("AMReceiverC", "(Receive) Entrei no switch do root node (0)\n");
      if(len == sizeof(SensorBroadCastMessage)){ // Recebeu uma msg do sensor node

        // Temos a mensagem enviada para o root
        dbg("AMReceiverC", "(Receive) I'am the root(%d) and I receive a msg from sensor node #%d\n", TOS_NODE_ID, msgReceive->nodeid);               

        // escrita no log
        logFile = fopen("logFile.txt", "ab+");
        if (logFile == NULL)
        {
          dbg("AMReceiverC", "Deu merda!");               
        }

        fprintf(logFile, "Receive temperature = %d by node #%d\n", msgReceive->temperature, msgReceive->nodeid);

        fclose(logFile);
      }
    }
    else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99) // routing nodes
    {
      nx_uint32_t msgsign;
      dbg("AMReceiverC", "(Receive) RouteNode received msg (#%d, seq=%d)\n", msgReceive->nodeid, msgReceive->msg_seq);
      msgsign = (msgReceive->nodeid&0xFFFF)<<16 | (msgReceive->msg_seq&0xFFFF);
      if (msgsign == lastRouted) {
        dbg("AMReceiverC", "(Receive) RouteNode discarding dup msg (#%d, seq=%d)\n", msgReceive->nodeid, msgReceive->msg_seq);
        return bufPtr;
      }
      else { lastRouted = msgsign; }
      
      //if (!busyRadio) {
        // TODO: Verificar se o módulo de rádio está ocupado...
        dbg("AMReceiverC", "(Receive) RouteNode rerouting msg (#%d, seq=%d)\n", msgReceive->nodeid, msgReceive->msg_seq);
        if (call AMSend.send(AM_BROADCAST_ADDR, bufPtr, sizeof(SensorBroadCastMessage)) == SUCCESS) {
            dbg("AMReceiverC", "(Receive) Dps do call ser um SUCCESS\n");
            busyRadio = TRUE;
        }
        else { dbg("AMReceiverC", "(Receive) RouteNode failed to reroute packet from sensor node #%d\n", msgReceive->nodeid); }
      //} else Queue.queue();
    }
    else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999) { // sensor nodes
    }
    else {
    }
    return bufPtr;
  }

  // TIMER EVENTS
  event void Timer.fired() {
    if(!busyRadio) {
        
        msgSend = (SensorBroadCastMessage*)(call Packet.getPayload(&messageRadio, sizeof(SensorBroadCastMessage)));
        msgSend->nodeid = TOS_NODE_ID;
        msgSend->msg_seq = ++msg_curr_seq; // Primeiro numero é 1, e não 0!
        msgSend->temperature = currentTemperature;
        
        dbg("ActiveMessageC", "(ActiveMessageC) Estou dentro do envio\n");
        if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorBroadCastMessage)) == SUCCESS) {
          dbg("ActiveMessageC", "(ActiveMessageC) Dps do call ser um SUCCESS\n");
          busyRadio = TRUE;
        }
      }
  }


  // SENSOR EVENTS
  event void Read.readDone(error_t result, uint16_t data) {
    if (result != SUCCESS){
      data = 0xffff;
    }
    // Se ainda n foi lido temperatura desde o ultimo envio-o de msg
    if (currentTemperature == -1){
      currentTemperature = data;      
    }
  }
}

