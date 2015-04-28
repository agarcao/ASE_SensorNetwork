#ifndef SENSOR_FIRE_LIB_H
#define SENSOR_FIRE_LIB_H

typedef nx_struct SensorBroadCastMessage {
  nx_uint16_t nodeid;
  nx_uint16_t msg_seq; // Para os routing nodes distinguirem as mensagens que já rotearam...
  nx_uint16_t temperature;
} SensorBroadCastMessage;

enum {
  AM_RADIO_SENSOR_FIRE_MSG = 6,

  // Intervalo entre envio-o de msg
  DEFAULT_INTERVAL = 256,
};

#endif