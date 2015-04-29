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
}
implementation
{
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
            msgDiscoverySend->sensorNodeId = TOS_NODE_ID;
            msgDiscoverySend->latitude = TOS_NODE_ID;
            msgDiscoverySend->longitude = TOS_NODE_ID;
            msgDiscoverySend->hop = 0;
        
            dbg("ActiveMessageC", "(AMControl.startDone) Enviou a mensage de discovery do sensor node #%d %d\n", TOS_NODE_ID);
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
    if(!TOS_NODE_ID){
      dbg("AMReceiverC", "(Receive) Entrei no switch do root node (0)\n");
      
      // Recebeu uma msg do sensor node do tipo Discovery
      if(len == sizeof(SensorNodeDiscoveryMessage)){
        
        msgDiscoveryReceive = (SensorNodeDiscoveryMessage*) payload;
        dbg("AMReceiverC", "(Receive) [%d][Root Node] I receive a DISCOVERY msg from sensor node #%d with #%d hops\n", 
          TOS_NODE_ID, 
          msgDiscoveryReceive->sensorNodeId,
          msgDiscoveryReceive->hop
        );               

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
      }
      // Se for uma mensagem do tipo 'SensorBroadCastMessage' (vêm com as leituras do sensor node)                       
      else if(len == sizeof(SensorBroadCastMessage)){

        msgBroadCastReceive = (SensorBroadCastMessage*) payload;
        dbg("AMReceiverC", "(Receive) [%d][Root Node] Recebi SensorBroadCastMessage do nó #%d\n", 
          TOS_NODE_ID,
          msgBroadCastReceive->sensorNodeId
        );

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
        dbg("AMReceiverC", "(Receive) [%d][Routing Node] Sou um routing node e rescebi discovery msg do nó #%d\n", 
          TOS_NODE_ID,
          msgDiscoveryReceive->sensorNodeId
        );               

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
      }      
      // Recebeu uma msg do sensor node do tipo BroadCast
      else if(len == sizeof(SensorBroadCastMessage)){         
        
        msgBroadCastReceive = (SensorBroadCastMessage*) payload;
        dbg("AMReceiverC", "(Receive) [%d][Routing Node] Sou um routing node e recebi BROADCAST msg do nó #%d\n", 
          TOS_NODE_ID, 
          msgBroadCastReceive->sensorNodeId
        );               

        // Enviar msg de resposta ao sensor node        
        msgBroadCastSend = (SensorBroadCastMessage*)
            (call Packet.getPayload(&messageRadio, sizeof(SensorBroadCastMessage)));

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
      }
      else{
        dbg("AMReceiverC", "(Receive) [%d][Routing Node] Não devo entrar aqui\n", TOS_NODE_ID);           
      }
    } 
    // sensor nodes
    else if(TOS_NODE_ID >= 100 && TOS_NODE_ID <= 999){ 
      if(len == sizeof(SensorNodeDiscoveryRspMessage) && dispatchNodeID == -1){ 
        // Recebeu uma msg de resposta ao Discovery do sensor node e ainda n tem nó de despacho
        msgDiscoveryRspReceive = (SensorNodeDiscoveryRspMessage*) payload;
        dbg("AMReceiverC", "(Receive) I'am the sensor node(%d) and I receive a discovery responde msg from node #%d\n", TOS_NODE_ID, msgDiscoveryRspReceive->dispatchNodeId);                       

        // se for para mim
        dispatchNodeID = (int)msgDiscoveryRspReceive->dispatchNodeId;

        // Timer já está a correr e portanto n precisamos de mais nda
      }
    } 
    else {
    }
    return bufPtr;
  }

  // TIMER EVENTS (SÓ OS SENSOR NODES É QUE FAZEM ESTE EVENTO)
  event void Timer.fired() {
    dbg("ActiveMessageC", "(Timer.fired) [%d] Timer desparou para o nó\n", TOS_NODE_ID);
    if(!busyRadio){
      // já encontramos o nó de dispatch para este sensor node
      if(dispatchNodeID != -1){

        msgBroadCastSend = (SensorBroadCastMessage*)
          (call Packet.getPayload(&messageRadio, sizeof(SensorBroadCastMessage)));
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

