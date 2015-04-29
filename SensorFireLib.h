#ifndef SENSOR_FIRE_LIB_H
#define SENSOR_FIRE_LIB_H

typedef nx_struct SensorNodeDiscoveryMessage {
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
  nx_uint16_t sensorNodeId;
  nx_uint16_t temperature;
  nx_uint16_t humidity;
} SensorBroadCastMessage;

typedef struct SensorFireMsg {
  short messageTypeId;
  union{
    SensorNodeDiscoveryMessage sensorNodeDiscoveryMessage;
    SensorNodeDiscoveryRspMessage sensorNodeDiscoveryRspMessage;
    SensorBroadCastMessage sensorBroadCastMessage;
  } messageType;
} SensorFireMsg;

enum {
  AM_RADIO_SENSOR_FIRE_MSG = 6,

  // Intervalo entre envio-o de msg
  DEFAULT_INTERVAL = 256,

  // Message Types
  SENSOR_NODE_DISCOVERY_MESSAGE = 1,
  SENSOR_NODE_DISCOVERY_RSP_MESSAGE = 2,
  SENSOR_NODE_BROADCAST_MESSAGE = 3
};

#endif