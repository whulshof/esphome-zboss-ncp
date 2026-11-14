// esphome: upstream keeps WiFi credentials of its own in NVS ("netcfg").
// Under ESPHome there are none; these stubs keep the firmware's restore and
// factory-reset paths compiling and make them skip the credential juggling.
#include "netcfg.h"

extern "C" bool netcfg_has_sta_creds(void) { return true; }
extern "C" esp_err_t netcfg_load(char*, size_t, char*, size_t) { return ESP_ERR_NOT_FOUND; }
extern "C" esp_err_t netcfg_persist(const char*, const char*) { return ESP_OK; }
extern "C" esp_err_t netcfg_clear(void) { return ESP_OK; }
