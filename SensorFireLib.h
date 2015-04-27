#ifndef SENSOR_FIRE_LIB_H
#define SENSOR_FIRE_LIB_H

typedef nx_struct SensorNodeDiscoveryMessage {
  nx_uint16_t nodeid;
  nx_uint16_t latitude;
  nx_uint16_t longitude;
} SensorNodeDiscoveryMessage;

typedef nx_struct SensorNodeDiscoveryRspMessage {
  nx_uint16_t dispatchNodeId;
} SensorNodeDiscoveryRspMessage;

typedef nx_struct SensorBroadCastMessage {
  nx_uint16_t nodeid;
  nx_uint16_t dispatchNodeId;
  nx_uint16_t temperature;
  nx_uint16_t humity;
  nx_uint32_t localTime;
} SensorBroadCastMessage;

enum {
  AM_RADIO_SENSOR_FIRE_MSG = 6,

  // Intervalo entre envio-o de msg
  DEFAULT_INTERVAL = 256,
};

#endif