#ifndef SENSOR_FIRE_LIB_H
#define SENSOR_FIRE_LIB_H

typedef nx_struct SensorNodeDiscoveryMessage {
  nx_uint32_t seqNumb;
  nx_uint16_t sensorNodeId;
  nx_uint16_t latitude;
  nx_uint16_t longitude;
  nx_uint16_t hop;
} SensorNodeDiscoveryMessage;

typedef nx_struct SensorNodeDiscoveryRspMessage {
  nx_uint16_t sensorNodeId;
  nx_uint16_t dispatchNodeId;
} SensorNodeDiscoveryRspMessage;

typedef nx_struct SensorBroadCastMessage {
  nx_uint32_t seqNumb;
  nx_uint16_t sensorNodeId;
  nx_uint16_t temperature;
  nx_uint16_t humidity;
} SensorBroadCastMessage;

typedef nx_struct DebugMessage {
  nx_uint16_t dbgMessCode;
  nx_uint16_t dbgParam1;
} DebugMessage;

typedef struct SensorFireMsg {
  short messageTypeId;
  union{
    SensorNodeDiscoveryMessage sensorNodeDiscoveryMessage;
    SensorNodeDiscoveryRspMessage sensorNodeDiscoveryRspMessage;
    SensorBroadCastMessage sensorBroadCastMessage;
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
  
  // Debug Messages
  DEBUG_MESSAGE = 20,     // Generic message code
  // The following tell what type of debug message it is.
  SETSMOKE_DBGMESSAGE       = 21, // Induces smoke near node, or reverts that operation

  // CACHE SIZE
  CACHE_SIZE = 10
};

#endif