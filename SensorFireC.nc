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

    //interface LocalTime<TMilli>;
  }
}
implementation
{
  // Variavel c/ o dispatch node ID
  int dispatchNodeID = -1;

  bool busyRadio = FALSE;
  message_t messageRadio;

  // Mensagens para os Discovery dos Sensor Nodes
  SensorNodeDiscoveryMessage *msgDiscoverySend, *msgDiscoveryReceive;

  // Mensagens para as respostas aos Discovery dos Sensor Nodes
  SensorNodeDiscoveryRspMessage *msgRespDiscoverySend, *msgDiscoveryRspReceive;

  // Mensagens c/ as mediçoes dos sensor nodes
  SensorBroadCastMessage *msgBroadCastSend, *msgBroadCastReceive;


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
    } 
    else {
      dbg("ActiveMessageC", "(AMControl.startDone) Inicialização Correta - Vamos mandar msg caso sejamos o sensor node\n");
      if(!TOS_NODE_ID){ // server node
        dbg("ActiveMessageC", "(AMControl.startDone) Server Node\n");
      } else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ // routing nodes
      } else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ // sensor nodes
        // Ao iniciar o modulo de comunicação, se o dispatch node ainda n for conhecido (=-1) temos de encontrar um
        if(dispatchNodeID == -1){
          if(!busyRadio){
        
            msgDiscoverySend = (SensorNodeDiscoveryMessage*)
              (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryMessage)));
            msgDiscoverySend->nodeid = TOS_NODE_ID;
            msgDiscoverySend->latitude = TOS_NODE_ID;
            msgDiscoverySend->longitude = TOS_NODE_ID;
        
            dbg("ActiveMessageC", "(AMControl.startDone) Enviou a mensage de discovery do sensor node #%d\n", TOS_NODE_ID);
            if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorNodeDiscoveryMessage)) == SUCCESS) {
              dbg("ActiveMessageC", "(AMControl.startDone) Sucessor a enviar a msg discovery do sensor node #%d\n", TOS_NODE_ID);
              busyRadio = TRUE;
            }
          }
        }
        else { 
          // Caso já tenhamos um nó de depacho associado, iniacializamos o timer para ler temperatura, etc de tempo a tempos
          dbg("ActiveMessageC", "(AMControl.startDone) Inicalizamos o timer para o nó #%d \n", TOS_NODE_ID);        
          call Timer.startPeriodic(DEFAULT_INTERVAL);        
        }
      } 
    }
  }

  event void AMControl.stopDone(error_t err) {
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) 
  {
    // Precisamos de dizer q o message buffer pode ser reutilizado
    dbg("AMReceiverC", "(AMSend.sendDone) Entro aqui %d\n", TOS_NODE_ID);
    if (&messageRadio == bufPtr) {
      dbg("AMReceiverC", "(AMSend.sendDone) Send Done %d\n", TOS_NODE_ID);
      busyRadio = FALSE;
    }
  }

  event message_t* Receive.receive(message_t* bufPtr, 
           void* payload, uint8_t len) 
  {
    dbg("AMReceiverC", "(Receive) Recebi msg\n");
    if(!TOS_NODE_ID){ // server node
      dbg("AMReceiverC", "(Receive) Entrei no switch do root node (0)\n");
      if(len == sizeof(SensorNodeDiscoveryMessage)){ 
        // Recebeu uma msg do sensor node do tipo Discovery

        msgDiscoveryReceive = (SensorNodeDiscoveryMessage*) payload;
        dbg("AMReceiverC", "(Receive) I'am the root(%d) and I receive a msg from sensor node #%d\n", TOS_NODE_ID, msgDiscoveryReceive->nodeid);               

        // escrita no log
        logFile = fopen("logFile.txt", "ab+");
        if (logFile == NULL)        {
          dbg("AMReceiverC", "(Receive) Deu merda!");               
        }

        fprintf(logFile, "Node with id #%d connected. Position is (%d, %d)\n", 
          msgDiscoveryReceive->nodeid, 
          msgDiscoveryReceive->latitude,
          msgDiscoveryReceive->longitude
        );

        fclose(logFile);

        // Enviar msg de resposta ao sensor node
        if(!busyRadio){
        
          msgRespDiscoverySend = (SensorNodeDiscoveryRspMessage*)
              (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryRspMessage)));
          msgRespDiscoverySend->dispatchNodeId = TOS_NODE_ID;
        
          dbg("ActiveMessageC", "(Receive) Enviou a mensage de resposta ao discovery do sensor node #%d\n", msgDiscoveryReceive->nodeid);
          if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorNodeDiscoveryRspMessage)) == SUCCESS) {
            dbg("ActiveMessageC", "(Receive) Sucesso a enviar a msg de resposta ao discovery do sensor node #%d\n", msgDiscoveryReceive->nodeid);
            busyRadio = TRUE;
          }
        }
      }
      else if(len == sizeof(SensorBroadCastMessage)){
        // Se for uma mensagem do tipo 'SensorBroadCastMessage' (vêm com as leituras do sensor node)                       
        msgBroadCastReceive = (SensorBroadCastMessage*) payload;
        dbg("AMReceiverC", "(Receive) Eu #%d recebi SensorBroadCastMessage do nó #%d\n", TOS_NODE_ID, msgBroadCastReceive->nodeid);
        if(msgBroadCastReceive->dispatchNodeId == TOS_NODE_ID){
          // Se for para este nó
          dbg("AMReceiverC", "(Receive) SensorBroadCastMessage é para mim\n");

          // escrita no log
          logFile = fopen("logFile.txt", "ab+");
          if (logFile == NULL)        {
            dbg("AMReceiverC", "(Receive) Deu merda!");               
          }

          fprintf(logFile, "[%d] Node with id #%d give temperature #%d and humity #%d\n", 
            (int)msgBroadCastReceive->localTime,
            (int)msgBroadCastReceive->nodeid, 
            (int)msgBroadCastReceive->temperature,
            (int)msgBroadCastReceive->humity
          );

          fclose(logFile);
        }
      } 
    } else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ // routing nodes
    } else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ // sensor nodes
      if(len == sizeof(SensorNodeDiscoveryRspMessage) && dispatchNodeID == -1){ 
        // Recebeu uma msg de resposta ao Discovery do sensor node e ainda n tem nó de despacho
        msgDiscoveryRspReceive = (SensorNodeDiscoveryRspMessage*) payload;
        dbg("AMReceiverC", "(Receive) I'am the sensor node(%d) and I receive a discovery responde msg from node #%d\n", TOS_NODE_ID, msgDiscoveryRspReceive->dispatchNodeId);                       

        dispatchNodeID = (int)msgDiscoveryRspReceive->dispatchNodeId;

        // Chamar o timer para começar a manda msg periodicamente
        dbg("ActiveMessageC", "(Receive) Inicalizamos o timer para o nó #%d \n", TOS_NODE_ID);        
        call Timer.startPeriodic(DEFAULT_INTERVAL);   
      }
    } else {
    }
    return bufPtr;
  }

  // TIMER EVENTS
  event void Timer.fired() {
    dbg("ActiveMessageC", "(Timer.fired) Timer desparou para o nó #%d\n", TOS_NODE_ID);
    if(!busyRadio){
        
        msgBroadCastSend = (SensorBroadCastMessage*)
          (call Packet.getPayload(&messageRadio, sizeof(SensorBroadCastMessage)));

        msgBroadCastSend->nodeid = TOS_NODE_ID;
        msgBroadCastSend->dispatchNodeId = dispatchNodeID;
        msgBroadCastSend->temperature = 0;
        msgBroadCastSend->humity = 0;
        msgBroadCastSend->localTime = 0;
        
        dbg("ActiveMessageC", "(Timer.fired) Nó #%d manda 'SensorBroadCastMessage' p/ o seu dispatch node #%d\n", TOS_NODE_ID, dispatchNodeID);
        if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorBroadCastMessage)) == SUCCESS) {
          dbg("ActiveMessageC", "(Timer.fired) Dps do call ser um SUCCESS\n");
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

