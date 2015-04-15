#ifndef SENSOR_FIRE_LIB_H
#define SENSOR_FIRE_LIB_H

typedef nx_struct SensorBroadCastMessage {
  nx_uint16_t nodeid;
} SensorBroadCastMessage;

enum {
  AM_RADIO_COUNT_MSG = 6,
};

#endif