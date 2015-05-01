#ifndef SENSOR_FIRE_LIB_H
#define SENSOR_FIRE_LIB_H

typedef nx_struct SensorNodeDiscoveryMessage {
  nx_uint32_t seqNumb;
  nx_uint16_t sensorNodeId;
  nx_uint16_t latitude;
  nx_uint16_t longitude;
  nx_uint16_t hop;
  nx_uint16_t firstTimeDiscovery;
} SensorNodeDiscoveryMessage;

typedef nx_struct SensorNodeDiscoveryRspMessage {
  nx_uint16_t sensorNodeId;
  nx_uint16_t dispatchNodeId;
} SensorNodeDiscoveryRspMessage;

typedef nx_struct SensorBroadCastMessage {
  nx_uint32_t seqNumb;
  nx_uint16_t sensorNodeId;
  nx_uint16_t dispatchNodeId; // Needed to know who must respond with SensorBroadCastRspMessage
  nx_uint16_t temperature;
  nx_uint16_t humidity;
} SensorBroadCastMessage;

typedef nx_struct SensorBroadCastRspMessage {
  nx_uint16_t sensorNodeId;
} SensorBroadCastRspMessage;

typedef struct SensorFireMsg {
  short messageTypeId;
  union{
    SensorNodeDiscoveryMessage sensorNodeDiscoveryMessage;
    SensorNodeDiscoveryRspMessage sensorNodeDiscoveryRspMessage;
    SensorBroadCastMessage sensorBroadCastMessage;
    SensorBroadCastRspMessage sensorBroadCastRspMessage;
  } messageType;
} SensorFireMsg;

// Cache Item
typedef nx_struct CacheItem {
  nx_uint16_t nodeId;
  nx_uint16_t seqNumb;
} CacheItem;

enum {
  AM_RADIO_SENSOR_FIRE_MSG = 6,

  // Intervalo entre envio-o de msg
  DEFAULT_INTERVAL = 256,

  // Message Types
  SENSOR_NODE_DISCOVERY_MESSAGE = 1,
  SENSOR_NODE_DISCOVERY_RSP_MESSAGE = 2,
  SENSOR_NODE_BROADCAST_MESSAGE = 3,
  SENSOR_NODE_BROADCAST_RSP_MESSAGE = 4,

  // CACHE SIZE
  CACHE_SIZE = 10,

  // Numero que nos diz qtas msg de BROADCAST são enviadas e n recebidos os respectivos acks 
  //  até que o processo DISCOVERY seja feito outra vez pelo sensor node 
  MAX_MISSING_ACKS_FROM_BROADCAST = 3
};

#endif