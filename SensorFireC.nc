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

    interface Queue<struct SensorFireMsg> as SendQueue;

    interface LocalTime<TMilli>;
  }
  provides
  {
    interface Cache<CacheItem>;
  }
}
implementation
{
  // Variaveis da Cache
  CacheItem cache[CACHE_SIZE];
  uint8_t first = 0;
  uint8_t count = 0;
  CacheItem cacheItem;
  int8_t cacheIndex;

  // Variavel c/ o dispatch node ID
  int dispatchNodeID = -1;

  bool busyRadio = FALSE;
  message_t messageRadio, messageToQueue;

  // Mensagens para os Discovery dos Sensor Nodes
  SensorNodeDiscoveryMessage *msgDiscoverySend, *msgDiscoveryReceive;

  // Mensagens para as respostas aos Discovery dos Sensor Nodes
  SensorNodeDiscoveryRspMessage *msgRespDiscoverySend, *msgDiscoveryRspReceive;

  // Mensagens c/ as mediçoes dos sensor nodes
  SensorBroadCastMessage *msgBroadCastSend, *msgBroadCastReceive;

  // Apontador para estrutuca SensorFireMsg
  SensorFireMsg structSensorFire;

  // Numero de sequencia das msg mandadas pelos sensor nodes
  uint32_t seqNumb = 0;

  // Boleano para dizer se routing nodes devem retrasmitir mensagens ou discartar
  bool retransmit;
  bool alreadyArrive;

  // Seguem-se os stats dos sensores. . .
  uint16_t currentTemperature;
  //bool CurrentSmoke = FALSE;

  FILE *logFile;

  /* FUNCTIONS DECLARATIONS */
  int8_t lookup(uint16_t nodeIdKey);


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
        if(dispatchNodeID == -1) {
          if(!busyRadio){
        
            msgDiscoverySend = (SensorNodeDiscoveryMessage*)
              (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryMessage)));
            msgDiscoverySend->seqNumb = ++seqNumb;
            msgDiscoverySend->sensorNodeId = TOS_NODE_ID;
            msgDiscoverySend->latitude = TOS_NODE_ID;
            msgDiscoverySend->longitude = TOS_NODE_ID;
            msgDiscoverySend->hop = 0;
        
            dbg("ActiveMessageC", "(AMControl.startDone) Enviou a mensage de discovery do sensor node #%d\n", TOS_NODE_ID);
            if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorNodeDiscoveryMessage)) == SUCCESS) {
              dbg("ActiveMessageC", "(AMControl.startDone) Sucessor a enviar a msg discovery do sensor node #%d\n", TOS_NODE_ID);
              busyRadio = TRUE;
            }
          }
        }
        // Caso já tenhamos um nó de depacho associado, iniacializamos o timer para ler temperatura, etc de tempo a tempos
        else {
          dbg("ActiveMessageC", "(AMControl.startDone) Inicalizamos o timer para o nó #%d \n", TOS_NODE_ID);        
          call Timer.startPeriodic(DEFAULT_INTERVAL);        
        }
      } 
    }
  }

  event void AMControl.stopDone(error_t err) {
    dbg("ActiveMessageC", "(AMControl.stopDone) vou aqui\n");
  }


  event void AMSend.sendDone(message_t* bufPtr, error_t error) 
  {
    dbg("AMReceiverC", "(AMSend.sendDone) [%d] Entro aqui\n", TOS_NODE_ID);
    // server node
    if(!TOS_NODE_ID){
      // verifica se msg teve errors de transmissão
      if (&messageRadio == bufPtr) {  
        // se há mensagens na queue para enviar
        if(!(call SendQueue.empty())){          
          dbg("AMReceiverC", "(AMSend.sendDone) [%d][Root Node] Há mais msg para enviar\n", TOS_NODE_ID); 
          structSensorFire = call SendQueue.dequeue();

          // Confirmamos que só pode ser uma messagem de discovery response a estar na SendQueue
          if(structSensorFire.messageTypeId == SENSOR_NODE_DISCOVERY_RSP_MESSAGE){

            msgRespDiscoverySend = (SensorNodeDiscoveryRspMessage*)
                  (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryRspMessage)));

            msgRespDiscoverySend->sensorNodeId = structSensorFire.messageType.sensorNodeDiscoveryRspMessage.sensorNodeId;
            msgRespDiscoverySend->dispatchNodeId = structSensorFire.messageType.sensorNodeDiscoveryRspMessage.dispatchNodeId;            

            if (call AMSend.send(msgRespDiscoverySend->sensorNodeId, &messageRadio, sizeof(SensorNodeDiscoveryRspMessage)) == SUCCESS) {
            }
          }
        }
        // caso n exista metemos radio disponivel
        else{
          // Se já n há
          dbg("AMReceiverC", "(AMSend.sendDone) [%d][Root Node] Queue está empty\n", TOS_NODE_ID);
          busyRadio = FALSE;
        }
      }    
    } 
    // routing nodes
    else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99){ 
      // verifica se msg teve errors de transmissão
      if (&messageRadio == bufPtr) { 
        // se há mensagens na queue para enviar
        if(!(call SendQueue.empty())){          
          dbg("AMReceiverC", "(AMSend.sendDone) [%d][Routing Node] Há mais msg para enviar\n", TOS_NODE_ID); 
          structSensorFire = call SendQueue.dequeue();

          // Se for uma msg do tipo discovery
          if(structSensorFire.messageTypeId == SENSOR_NODE_DISCOVERY_MESSAGE){
            dbg("AMReceiverC", "(AMSend.sendDone) [%d][Routing Node] É uma mensage do tipo DISCOVERY\n", TOS_NODE_ID); 
            msgDiscoverySend = (SensorNodeDiscoveryMessage*)
                  (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryMessage)));
            // construimos a msg
            msgDiscoverySend->seqNumb = structSensorFire.messageType.sensorNodeDiscoveryMessage.seqNumb;
            msgDiscoverySend->sensorNodeId = structSensorFire.messageType.sensorNodeDiscoveryMessage.sensorNodeId;
            msgDiscoverySend->latitude = structSensorFire.messageType.sensorNodeDiscoveryMessage.latitude;
            msgDiscoverySend->longitude = structSensorFire.messageType.sensorNodeDiscoveryMessage.longitude;
            msgDiscoverySend->hop = structSensorFire.messageType.sensorNodeDiscoveryMessage.hop;

            if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorNodeDiscoveryMessage)) == SUCCESS) {
            }
          }
          // Se for uma msg do tipo discovery response
          else if(structSensorFire.messageTypeId == SENSOR_NODE_DISCOVERY_RSP_MESSAGE){
            dbg("AMReceiverC", "(AMSend.sendDone) [%d][Routing Node] É uma mensage do tipo DISCOVERY_RSP\n", TOS_NODE_ID); 
            msgRespDiscoverySend = (SensorNodeDiscoveryRspMessage*)
                  (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryRspMessage)));
            // construimos a msg
            msgRespDiscoverySend->sensorNodeId = structSensorFire.messageType.sensorNodeDiscoveryRspMessage.sensorNodeId;
            msgRespDiscoverySend->dispatchNodeId = structSensorFire.messageType.sensorNodeDiscoveryRspMessage.dispatchNodeId;

            if (call AMSend.send(msgRespDiscoverySend->sensorNodeId, &messageRadio, sizeof(SensorNodeDiscoveryRspMessage)) == SUCCESS) {
            }
          }
          // se for uma msg do tipo broadcast
          else if(structSensorFire.messageTypeId == SENSOR_NODE_BROADCAST_MESSAGE){
            dbg("AMReceiverC", "(AMSend.sendDone) [%d][Routing Node] É uma mensage do tipo BROADCAST\n", TOS_NODE_ID); 
            msgBroadCastSend = (SensorBroadCastMessage*)
                  (call Packet.getPayload(&messageRadio, sizeof(SensorBroadCastMessage)));
            // construimos a msg
            msgBroadCastSend->seqNumb = structSensorFire.messageType.sensorBroadCastMessage.seqNumb;
            msgBroadCastSend->sensorNodeId = structSensorFire.messageType.sensorBroadCastMessage.sensorNodeId;
            msgBroadCastSend->temperature = structSensorFire.messageType.sensorBroadCastMessage.temperature;
            msgBroadCastSend->humidity = structSensorFire.messageType.sensorBroadCastMessage.humidity;

            if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorBroadCastMessage)) == SUCCESS) {
            }
          }
          // n devia entrar aqui
          else{
            dbg("AMReceiverC", "(AMSend.sendDone) [%d][Routing Node] N devia entrar aqui\n", TOS_NODE_ID); 
          }          
        }
        else{
          // Se já n há
          dbg("AMReceiverC", "(AMSend.sendDone) [%d][Routing Node] Queue está empty\n", TOS_NODE_ID);
          busyRadio = FALSE;
        }
      }
    }
    // sensor nodes
    else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ 
      // verifica se msg teve errors de transmissão
      if (&messageRadio == bufPtr) {   
        // Ainda n tenho o meu dispatch node definido       
        if (dispatchNodeID == -1){
          dbg("AMReceiverC", "(AMSend.sendDone) [%d][Sensor Node] Ainda nao tenho o meu Dispatch Node definido\n", TOS_NODE_ID);

          // Inicializamos timer para voltar a enviar msg de discovery enquanto n tivemos um dispatch node
          dbg("AMReceiverC", "(AMSend.sendDone) [%d][Sensor Node] Inicializo timer para mandar nova discovery msg ao fim de %d\n", TOS_NODE_ID, DEFAULT_INTERVAL);
          busyRadio = FALSE;
          call Timer.startPeriodic(DEFAULT_INTERVAL);
        }        
        else if(!(call SendQueue.empty())){
          // se há mensagens na queue para enviar
          dbg("AMReceiverC", "(AMSend.sendDone) [%d] Há mais msg para enviar\n", TOS_NODE_ID); 
          /*messageRadio = call SendQueue.dequeue();
          msgRespDiscoverySend = (SensorNodeDiscoveryRspMessage*)
                (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryRspMessage)));

          if (call AMSend.send(msgRespDiscoverySend->sensorNodeId, &messageRadio, sizeof(SensorNodeDiscoveryRspMessage)) == SUCCESS) {
          }*/
        }
        else{
          // Se já n há
          dbg("AMReceiverC", "(AMSend.sendDone) [%d] Queue está empty\n", TOS_NODE_ID);
          busyRadio = FALSE;
        }
      }
    } 
    else {
      dbg("AMReceiverC", "(AMSend.sendDone) Não devia entrar aqui. Nó n está em nenhuma das regras\n");
    }
  }


  event message_t* Receive.receive(message_t* bufPtr, 
           void* payload, uint8_t len) 
  {
    dbg("AMReceiverC", "(Receive) Recebi msg\n");
    
    // server node
    if(!TOS_NODE_ID) {
      dbg("AMReceiverC", "(Receive) Entrei no switch do root node (0)\n");
      
      // Recebeu uma msg do sensor node do tipo Discovery
      if(len == sizeof(SensorNodeDiscoveryMessage)){
        
        msgDiscoveryReceive = (SensorNodeDiscoveryMessage*) payload;
        dbg("AMReceiverC", "(Receive) [%d][Root Node] I receive a DISCOVERY msg from sensor node #%d with #%d hops\n", 
          TOS_NODE_ID, 
          msgDiscoveryReceive->sensorNodeId,
          msgDiscoveryReceive->hop
        );

        // Temos de verificar se este msg já chegou ao root
        alreadyArrive = FALSE;
        cacheIndex = lookup(msgDiscoveryReceive->sensorNodeId);

        // Existe informações deste sensor node
        if(cacheIndex != -1){
          cacheItem = cache[cacheIndex];
          dbg("AMReceiverC", "(Receive) [%d][Routing Node] Existe info sobre este nó #%d (seqNumb: %d)\n",
            TOS_NODE_ID,
            cacheItem.nodeId,
            cacheItem.seqNumb
          );

          // Já passou por aqui
          if(cacheItem.seqNumb >= msgDiscoveryReceive->seqNumb){
            alreadyArrive = TRUE;
            dbg("AMReceiverC", "(Receive) [%d][Routing Node] Msg c/ seqNumb #%d do nodeId #%d já passou por aqui.\n",
              TOS_NODE_ID,
              msgDiscoveryReceive->seqNumb,
              msgDiscoveryReceive->sensorNodeId
            );
          }
        }               

        // Vemos se esta msg já chegou ao root (ou seja é info repetida)
        if(!alreadyArrive){
          // escrita no log
          logFile = fopen("logFile.txt", "ab+");
          if (logFile == NULL)        {
            dbg("AMReceiverC", "(Receive) Deu merda!");               
          }

          dbg("AMReceiverC", "(Receive) vou printar no log '[%d] Node with id #%d connected. Position is (%d, %d)'\n", 
            call LocalTime.get(), 
            msgDiscoveryReceive->sensorNodeId, 
            msgDiscoveryReceive->latitude,
            msgDiscoveryReceive->longitude
          );

          fprintf(logFile, "[%d] Node with id #%d connected. Position is (%d, %d)\n",
            call LocalTime.get(), 
            msgDiscoveryReceive->sensorNodeId, 
            msgDiscoveryReceive->latitude,
            msgDiscoveryReceive->longitude
          );

          fclose(logFile);

          // só retrasmitimos se for realmente dum sensor node
          if(!msgDiscoveryReceive->hop){
            // Radio n está ocupado para send
            dbg("AMReceiverC", "(Receive) [%d][Root Node] DISCOVERY msg era para mim. Vou enviar resposta. HOP=%d\n",
              TOS_NODE_ID,
              msgDiscoveryReceive->hop
            );

            if(!busyRadio){
              // Enviar msg de resposta ao sensor node
              msgRespDiscoverySend = (SensorNodeDiscoveryRspMessage*)
                  (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryRspMessage)));

              msgRespDiscoverySend->sensorNodeId = msgDiscoveryReceive->sensorNodeId;
              msgRespDiscoverySend->dispatchNodeId = TOS_NODE_ID;
            
              dbg("ActiveMessageC", "(Receive) Enviou a mensage de resposta ao discovery do sensor node #%d\n", 
                msgDiscoveryReceive->sensorNodeId
              );

              if (call AMSend.send(msgRespDiscoverySend->sensorNodeId, &messageRadio, sizeof(SensorNodeDiscoveryRspMessage)) == SUCCESS) {
                dbg("ActiveMessageC", "(Receive) Sucesso a enviar a msg de resposta ao discovery do sensor node #%d\n", 
                  msgDiscoveryReceive->sensorNodeId
                );
                busyRadio = TRUE;
              }
            }
            // Radio ocupado. Temos que por na queue
            else{
              dbg("ActiveMessageC", "(Receive) Radio esta busy. Põe na queue");

              msgRespDiscoverySend = (SensorNodeDiscoveryRspMessage*)
                  (call Packet.getPayload(&messageToQueue, sizeof(SensorNodeDiscoveryRspMessage)));
              msgRespDiscoverySend->sensorNodeId = msgDiscoveryReceive->sensorNodeId;
              msgRespDiscoverySend->dispatchNodeId = TOS_NODE_ID;

              structSensorFire.messageTypeId = SENSOR_NODE_DISCOVERY_RSP_MESSAGE;
              structSensorFire.messageType.sensorNodeDiscoveryRspMessage = *msgRespDiscoverySend;

              call SendQueue.enqueue(structSensorFire);
            }
          }

          dbg("ActiveMessageC", "(Receive) [%d][Root Node] Pomos informacaos do seq number e node id na CACHE (sensorNodeId : %d) (seq : %d)\n", 
            TOS_NODE_ID,
            msgDiscoveryReceive->sensorNodeId,
            msgDiscoveryReceive->seqNumb
          );
          // Por fim vamos actualizar a informação na cache
          cacheItem.nodeId = msgDiscoveryReceive->sensorNodeId;
          cacheItem.seqNumb = msgDiscoveryReceive->seqNumb;

          call Cache.insert(cacheItem);
        }
        else{
          dbg("ActiveMessageC", "(Receive) [%d][Root Node] Msg descartada pois seq number da cache maior ou igual que o da msg (sensorNodeId : %d) (seqCache : %d) (seqMsg : %d)\n",
             TOS_NODE_ID,
             msgDiscoveryReceive->sensorNodeId,
             cacheItem.seqNumb,
             msgDiscoveryReceive->seqNumb
          );
        }
      }
      // Se for uma mensagem do tipo 'SensorBroadCastMessage' (vêm com as leituras do sensor node)                       
      else if(len == sizeof(SensorBroadCastMessage)){

        msgBroadCastReceive = (SensorBroadCastMessage*) payload;
        dbg("AMReceiverC", "(Receive) [%d][Root Node] Recebi SensorBroadCastMessage do nó #%d\n", 
          TOS_NODE_ID,
          msgBroadCastReceive->sensorNodeId
        );

        // Temos de verificar se este msg já chegou ao root
        alreadyArrive = FALSE;
        cacheIndex = lookup(msgBroadCastReceive->sensorNodeId);

        // Existe informações deste sensor node
        if(cacheIndex != -1){
          cacheItem = cache[cacheIndex];
          dbg("AMReceiverC", "(Receive) [%d][Routing Node] Existe info sobre este nó #%d (seqNumb: %d)\n",
            TOS_NODE_ID,
            cacheItem.nodeId,
            cacheItem.seqNumb
          );

          // Já passou por aqui
          if(cacheItem.seqNumb >= msgBroadCastReceive->seqNumb){
            alreadyArrive = TRUE;
            dbg("AMReceiverC", "(Receive) [%d][Routing Node] Msg c/ seqNumb #%d do nodeId #%d já passou por aqui.\n",
              TOS_NODE_ID,
              msgBroadCastReceive->seqNumb,
              msgBroadCastReceive->sensorNodeId
            );
          }
        }    

        // Vemos se esta msg já chegou ao root (ou seja é info repetida)
        if(!alreadyArrive){
          // escrita no log
          logFile = fopen("logFile.txt", "ab+");
          if (logFile == NULL)        {
            dbg("AMReceiverC", "(Receive) Deu merda!");               
          }

          dbg("AMReceiverC", "(Receive) vou printar no log '%d] Node with id #%d give temperature #%d and humity #%d'\n", 
            call LocalTime.get(),
            (int)msgBroadCastReceive->sensorNodeId, 
            (int)msgBroadCastReceive->temperature,
            (int)msgBroadCastReceive->humidity
          );

          fprintf(logFile, "[%d] Node with id #%d give temperature #%d and humity #%d\n", 
            call LocalTime.get(),
            (int)msgBroadCastReceive->sensorNodeId, 
            (int)msgBroadCastReceive->temperature,
            (int)msgBroadCastReceive->humidity
          );

          fclose(logFile);

          dbg("ActiveMessageC", "(Receive) [%d][Root Node] Pomos informacaos do seq number e node id na CACHE (sensorNodeId : %d) (seq : %d)\n", 
            TOS_NODE_ID,
            msgBroadCastReceive->sensorNodeId,
            msgBroadCastReceive->seqNumb
          );

          // Por fim vamos actualizar a informação na cache
          cacheItem.nodeId = msgBroadCastReceive->sensorNodeId;
          cacheItem.seqNumb = msgBroadCastReceive->seqNumb;

          call Cache.insert(cacheItem);
        }
        else{
          dbg("ActiveMessageC", "(Receive) [%d][Root Node] Msg descartada pois seq number da cache maior ou igual que o da msg (sensorNodeId : %d) (seqCache : %d) (seqMsg : %d)\n",
             TOS_NODE_ID,
             msgBroadCastReceive->sensorNodeId,
             cacheItem.seqNumb,
             msgBroadCastReceive->seqNumb
          );
        }
      }
      else{
          dbg("AMReceiverC", "(Receive) [%d][Root Node] Não devo entrar aqui\n", TOS_NODE_ID);          
      }
    }
    // routing nodes 
    else if(TOS_NODE_ID >= 1 && TOS_NODE_ID <= 99)
    {
      dbg("AMReceiverC", "(Receive) [%d][Routing Node] Entrei no switch do routing node\n", 
        TOS_NODE_ID
      );
      // Recebeu uma msg do sensor node do tipo Discovery
      if(len == sizeof(SensorNodeDiscoveryMessage)){         
        
        msgDiscoveryReceive = (SensorNodeDiscoveryMessage*) payload;
        dbg("AMReceiverC", "(Receive) [%d][Routing Node] Sou um routing node e rescebi discovery msg do nó #%d com nº seq #%d\n", 
          TOS_NODE_ID,
          msgDiscoveryReceive->sensorNodeId,
          msgDiscoveryReceive->seqNumb
        );

        // Temos de verificar se msg já não passou por este routing node
        retransmit = TRUE;
        cacheIndex = lookup(msgDiscoveryReceive->sensorNodeId);
        dbg("AMReceiverC", "(Receive) [%d][Routing Node] CacheIndex = #%d\n", 
          TOS_NODE_ID,
          cacheIndex
        );

        // Existe informações deste sensor node
        if(cacheIndex != -1){
          cacheItem = cache[cacheIndex];
          dbg("AMReceiverC", "(Receive) [%d][Routing Node] Existe info sobre este nó #%d (seqNumb: %d)\n",
            TOS_NODE_ID,
            cacheItem.nodeId,
            cacheItem.seqNumb
          );

          // Já passou por aqui
          if(cacheItem.seqNumb >= msgDiscoveryReceive->seqNumb){
            retransmit = FALSE;
            dbg("AMReceiverC", "(Receive) [%d][Routing Node] Msg c/ seqNumb #%d do nodeId #%d já passou por aqui.\n",
              TOS_NODE_ID,
              msgDiscoveryReceive->seqNumb,
              msgDiscoveryReceive->sensorNodeId
            );
          }
        }

        // Vemos se é para retrasmitir
        if(retransmit){
          // Enviar msg de resposta ao sensor node
          msgRespDiscoverySend = (SensorNodeDiscoveryRspMessage*)
              (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryRspMessage)));
          msgRespDiscoverySend->sensorNodeId = msgDiscoveryReceive->sensorNodeId;
          msgRespDiscoverySend->dispatchNodeId = TOS_NODE_ID;
          
          // Radio esta disponivel? 
          if(!busyRadio){
            dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Enviou a mensage de resposta ao discovery do sensor node #%d\n", 
              TOS_NODE_ID, 
              msgDiscoveryReceive->sensorNodeId
            );

            if (call AMSend.send(msgRespDiscoverySend->sensorNodeId, &messageRadio, sizeof(SensorNodeDiscoveryRspMessage)) == SUCCESS) {
              dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Sucesso a enviar a msg de resposta ao discovery do sensor node #%d\n",
               TOS_NODE_ID, 
               msgDiscoveryReceive->sensorNodeId
              );
              busyRadio = TRUE;
            }
          }
          // Radio n está disponivel. Tem que por na queue
          else{
            
            dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Radio esta busy. Põe na queue a msg de resposta ao discovery\n", 
              TOS_NODE_ID
            );          

            structSensorFire.messageTypeId = SENSOR_NODE_DISCOVERY_RSP_MESSAGE;
            structSensorFire.messageType.sensorNodeDiscoveryRspMessage = *msgRespDiscoverySend;

            call SendQueue.enqueue(structSensorFire);
          }

          // msg para retransmitir info inicial do sensor node ao root node
          dbg("ActiveMessageC", "(Receive) [%d] Radio esta busy. Põe a retrasmissão da msg de discovery\n", 
            TOS_NODE_ID
          );

          msgDiscoverySend = (SensorNodeDiscoveryMessage*)
                (call Packet.getPayload(&messageToQueue, sizeof(SensorNodeDiscoveryMessage)));
          msgDiscoverySend->seqNumb = msgDiscoveryReceive->seqNumb;    
          msgDiscoverySend->sensorNodeId = msgDiscoveryReceive->sensorNodeId;
          msgDiscoverySend->latitude = msgDiscoveryReceive->latitude;
          msgDiscoverySend->longitude = msgDiscoveryReceive->longitude;
          msgDiscoverySend->hop = (msgDiscoveryReceive->hop + 1);

          dbg("ActiveMessageC", "(Receive) [%d][Routing Node] DISCOVERY msg with fields (sensorNodeId : %d) (latitude : %d) (longitude : %d) (hops : %d) put in queue\n", 
            TOS_NODE_ID,
            msgDiscoverySend->sensorNodeId,
            msgDiscoverySend->latitude,
            msgDiscoverySend->longitude,
            msgDiscoverySend->hop
          );

          structSensorFire.messageTypeId = SENSOR_NODE_DISCOVERY_MESSAGE;
          structSensorFire.messageType.sensorNodeDiscoveryMessage = *msgDiscoverySend;

          call SendQueue.enqueue(structSensorFire);

          dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Pomos informacaos do seq number e node id na CACHE (sensorNodeId : %d) (seq : %d)\n", 
            TOS_NODE_ID,
            msgDiscoverySend->sensorNodeId,
            msgDiscoverySend->seqNumb
          );
          // Por fim vamos actualizar a informação na cache
          cacheItem.nodeId = msgDiscoveryReceive->sensorNodeId;
          cacheItem.seqNumb = msgDiscoveryReceive->seqNumb;

          call Cache.insert(cacheItem);
        }
        // Descarta se a msg pois já passou por aqui
        else{
          dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Msg descartada pois seq number da cache maior ou igual que o da msg (sensorNodeId : %d) (seqCache : %d) (seqMsg : %d)\n",
             TOS_NODE_ID,
             msgDiscoveryReceive->sensorNodeId,
             cacheItem.seqNumb,
             msgDiscoveryReceive->seqNumb
          );
        }
      }      
      // Recebeu uma msg do sensor node do tipo BroadCast
      else if(len == sizeof(SensorBroadCastMessage)){         
        
        msgBroadCastReceive = (SensorBroadCastMessage*) payload;
        dbg("AMReceiverC", "(Receive) [%d][Routing Node] Sou um routing node e recebi BROADCAST msg do nó #%d\n", 
          TOS_NODE_ID, 
          msgBroadCastReceive->sensorNodeId
        );          

        // Temos de verificar se msg já não passou por este routing node
        retransmit = TRUE;
        cacheIndex = lookup(msgBroadCastReceive->sensorNodeId);
        dbg("AMReceiverC", "(Receive) [%d][Routing Node] CacheIndex = #%d\n", 
          TOS_NODE_ID,
          cacheIndex
        );

        // Existe informações deste sensor node
        if(cacheIndex != -1){
          cacheItem = cache[cacheIndex];
          dbg("AMReceiverC", "(Receive) [%d][Routing Node] Existe info sobre este nó #%d (seqNumb: %d)\n",
            TOS_NODE_ID,
            cacheItem.nodeId,
            cacheItem.seqNumb
          );

          // Já passou por aqui
          if(cacheItem.seqNumb >= msgBroadCastReceive->seqNumb){
            dbg("AMReceiverC", "(Receive) [%d][Routing Node] Msg c/ seqNumb #%d do nodeId #%d já passou por aqui.\n",
              TOS_NODE_ID,
              msgBroadCastReceive->seqNumb,
              msgBroadCastReceive->sensorNodeId
            );
            retransmit = FALSE;
          }
        }



        if(retransmit){     

          // Enviar msg de resposta ao sensor node        
          msgBroadCastSend = (SensorBroadCastMessage*)
              (call Packet.getPayload(&messageRadio, sizeof(SensorBroadCastMessage)));

          msgBroadCastSend->seqNumb = msgBroadCastReceive->seqNumb;
          msgBroadCastSend->sensorNodeId = msgBroadCastReceive->sensorNodeId;
          msgBroadCastSend->temperature = msgBroadCastReceive->temperature;
          msgBroadCastSend->humidity = msgBroadCastReceive->humidity;
          
          
          // Radio esta disponivel? 
          if(!busyRadio){
            dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Retrasmiti a BROADCAST msg vinda do nó #%d\n", 
              TOS_NODE_ID, 
              msgBroadCastReceive->sensorNodeId
            );

            if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorBroadCastMessage)) == SUCCESS) {
              dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Sucesso a  Retrasmiti a BROADCAST msg vinda do nó #%d\n", 
                TOS_NODE_ID, 
                msgBroadCastReceive->sensorNodeId
              );
              busyRadio = TRUE;
            }
          }
          // Radio n está disponivel. Tem que por na queue
          else{
            
            dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Radio esta busy. Põe na queue a msg BROADCAST para retrasmitir\n", 
              TOS_NODE_ID
            );          

            structSensorFire.messageTypeId = SENSOR_NODE_BROADCAST_MESSAGE;
            structSensorFire.messageType.sensorBroadCastMessage = *msgBroadCastSend;

            call SendQueue.enqueue(structSensorFire);
          }

          dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Pomos informacaos do seq number e node id na CACHE (sensorNodeId : %d) (seq : %d)\n", 
            TOS_NODE_ID,
            msgBroadCastSend->sensorNodeId,
            msgBroadCastSend->seqNumb
          );

          // Por fim vamos actualizar a informação na cache
          cacheItem.nodeId = msgBroadCastReceive->sensorNodeId;
          cacheItem.seqNumb = msgBroadCastReceive->seqNumb;

          call Cache.insert(cacheItem);
        }
        // Descarta se a msg pois já passou por aqui
        else{
          dbg("ActiveMessageC", "(Receive) [%d][Routing Node] Msg descartada pois seq number da cache maior ou igual que o da msg (sensorNodeId : %d) (seqCache : %d) (seqMsg : %d)\n",
             TOS_NODE_ID,
             msgBroadCastReceive->sensorNodeId,
             cacheItem.seqNumb,
             msgBroadCastReceive->seqNumb
          );
        }        
      }
      else{
        dbg("AMReceiverC", "(Receive) [%d][Routing Node] Não devo entrar aqui\n", TOS_NODE_ID);           
      }
    } 
    // sensor nodes
    else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999) {
      if(len == sizeof(SensorNodeDiscoveryRspMessage) && dispatchNodeID == -1) {
        // Recebeu uma msg de resposta ao Discovery do sensor node e ainda n tem nó de despacho
        msgDiscoveryRspReceive = (SensorNodeDiscoveryRspMessage*) payload;
        dbg("AMReceiverC", "(Receive) I'am the sensor node(%d) and I receive a discovery response msg from node #%d\n", TOS_NODE_ID, msgDiscoveryRspReceive->dispatchNodeId);

        // se for para mim
        dispatchNodeID = (int)msgDiscoveryRspReceive->dispatchNodeId;

        // Timer já está a correr e portanto n precisamos de mais nda
      }
      else if(len == sizeof(DebugMessage) && dispatchNodeID == -1) {
        DebugMessage *dbgMessageReceived = (void*)payload;
        switch (dbgMessageReceived->dbgMessCode) {
          case SETSMOKE_DBGMESSAGE:
            dbg("AMReceiverC", "Call for smoke!.....\n");
            break;
          default:
            dbg("AMReceiverC", "(Receive) Received invalid debug message; code %d\n", dbgMessageReceived->dbgMessCode);
        }
      }
    } 
    else {
    }
    return bufPtr;
  }

  // TIMER EVENTS (SÓ OS SENSOR NODES É QUE FAZEM ESTE EVENTO)
  event void Timer.fired() 
  {
    dbg("ActiveMessageC", "(Timer.fired) [%d] Timer desparou para o nó\n", TOS_NODE_ID);
    if(!busyRadio){
      // já encontramos o nó de dispatch para este sensor node
      if(dispatchNodeID != -1){

        msgBroadCastSend = (SensorBroadCastMessage*)
          (call Packet.getPayload(&messageRadio, sizeof(SensorBroadCastMessage)));
        msgBroadCastSend->seqNumb = ++seqNumb;
        msgBroadCastSend->sensorNodeId = TOS_NODE_ID;
        msgBroadCastSend->temperature = 0;
        msgBroadCastSend->humidity = 0;
        
        dbg("ActiveMessageC", "(Timer.fired) Nó #%d manda 'SensorBroadCastMessage' p/ o seu dispatch node #%d\n", TOS_NODE_ID, dispatchNodeID);
        if (call AMSend.send(dispatchNodeID, &messageRadio, sizeof(SensorBroadCastMessage)) == SUCCESS) {
          dbg("ActiveMessageC", "(Timer.fired) Dps do call ser um SUCCESS\n");
          busyRadio = TRUE;
        }
      }
      else{
        // ainda n encontramos o dispatch node por isso enviamos msg de discovery outra vez
        msgDiscoverySend = (SensorNodeDiscoveryMessage*)
              (call Packet.getPayload(&messageRadio, sizeof(SensorNodeDiscoveryMessage)));

        msgDiscoverySend->seqNumb = ++seqNumb;
        msgDiscoverySend->sensorNodeId = TOS_NODE_ID;
        msgDiscoverySend->latitude = TOS_NODE_ID;
        msgDiscoverySend->longitude = TOS_NODE_ID;
        
        dbg("ActiveMessageC", "(AMControl.startDone) Enviou a mensage de discovery do sensor node #%d\n", TOS_NODE_ID);
        if (call AMSend.send(AM_BROADCAST_ADDR, &messageRadio, sizeof(SensorNodeDiscoveryMessage)) == SUCCESS) {
          dbg("ActiveMessageC", "(AMControl.startDone) Sucessor a enviar a msg discovery do sensor node #%d\n", TOS_NODE_ID);
          busyRadio = TRUE;
        }          
      }
    }
    else{
      //sensor node n devia aconter
      dbg("ActiveMessageC", "(Timer.fired) [%d] Channel Busy. Não devia acontecer.\n", TOS_NODE_ID);
    }
  }


  // SENSOR EVENTS
  event void Read.readDone(error_t result, uint16_t data) 
  {
    if (result != SUCCESS){
      data = 0xffff;
    }
    // Se ainda n foi lido temperatura desde o ultimo envio-o de msg
    if (currentTemperature == -1){
      currentTemperature = data;      
    }
  }


  // CACHE FUNCTIONS
  /* if key is in cache returns the index (offset by first), otherwise returns count */
  int8_t lookup(uint16_t nodeIdKey) {
    uint8_t i;
    CacheItem item;
    
    dbg("AMReceiverC", "(lookup) Procuramos nó #%d com o count = %d e first = %d\n",
      nodeIdKey,
      count,
      first
    );
    for (i = 0; i < count; i++) {
      item = cache[(i + first) % CACHE_SIZE];
      if (item.nodeId == nodeIdKey){
        return i; 
      }
    }
    dbg("AMReceiverC", "(lookup) Não encontrei. retorno -1\n");
    return -1;
  }

  /* remove the entry with index i (relative to first) */
  void remove(uint8_t i) {
    uint8_t j;
    if (i >= count) 
      return;
    if (i == 0) {
      //shift all by moving first
      first = (first + 1) % CACHE_SIZE;
    } 
    else {
      //shift everyone down
      for (j = i; j < count; j++) {
        cache[(j + first) % CACHE_SIZE] = cache[(j + first + 1) % CACHE_SIZE];
      }
    }
    count--;
  }

  command void Cache.insert(CacheItem _cacheItem) {
    int8_t _cacheIndex;

    _cacheIndex = lookup(_cacheItem.nodeId);
    // se ja existir a key na cache
    if(_cacheIndex != -1){
      cache[_cacheIndex] = _cacheItem;
    }
    // se tiver cheia e n existir
    else if (count == CACHE_SIZE) {
      remove(_cacheIndex % count);
      cache[(first + count) % CACHE_SIZE] = _cacheItem;
      count++;
    }
    // se n tiver cheia e n existir
    else{
      cache[(first + count) % CACHE_SIZE] = _cacheItem;
      count++;
    }
  }

  // Se existe ou não
  command bool Cache.lookup(CacheItem _cacheItem) {
    return (lookup(_cacheItem.nodeId) < count);
  }

  // Remove todos os elementos
  command void Cache.flush() {
    while(count > 0)
      remove(0);
  }
}

