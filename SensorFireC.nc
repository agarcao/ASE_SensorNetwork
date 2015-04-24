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

  SensorBroadCastMessage *msgSend, *msgReceive;

  nx_uint16_t currentTemperature;

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
    dbg("Boot", "(Boot) Initializa AMControl");      
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) 
  {
    dbg("ActiveMessageC", "(AMControl.startDone) Inicialização do modulo de Comunicação\n");
    if (err != SUCCESS) {
      
      dbg("ActiveMessageC", "(AMControl.startDone) Erro na inicialização\n");
      call AMControl.start();
    } else {

      dbg("ActiveMessageC", "(AMControl.startDone) Inicialização Correta - Vamos mandar msg caso sejamos o sensor node\n");
      if(!TOS_NODE_ID){ // server node
        dbg("ActiveMessageC", "(AMControl.startDone) Server Node\n");
      } else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ // routing nodes
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
    if(!TOS_NODE_ID){ // server node
      dbg("AMReceiverC", "(Receive) Entrei no switch do root node (0)\n");
      if(len == sizeof(SensorBroadCastMessage)){ // Recebeu uma msg do sensor node

        // Temos a mensagem enviada para o root
        msgReceive = (SensorBroadCastMessage*) payload;
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
    } else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ // routing nodes
    } else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ // sensor nodes
    } else {
    }
    return bufPtr;
  }

  // TIMER EVENTS
  event void Timer.fired() {
    if(!busyRadio){
        
        msgSend = (SensorBroadCastMessage*)(call Packet.getPayload(&messageRadio, sizeof(SensorBroadCastMessage)));
        msgSend->nodeid = TOS_NODE_ID;
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

