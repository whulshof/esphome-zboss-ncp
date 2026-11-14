#pragma once
//
// esphome: replaces upstream's wifi_coex (own WiFi STA, Improv, mDNS).
// The network is ESPHome's (WiFi or Ethernet, optionally WireGuard). The
// firmware keeps calling the same entry points; they now ask ESPHome through
// the hooks in zboss_ncp.h (ncp_host_set_hooks).
//
#include <esp_err.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t wifi_coex_init(void);                 // no-op: ESPHome brings up the network
void      wifi_coex_enable_radio_coex(void);    // esp_coex_wifi_i154_enable() when ESPHome uses WiFi
esp_err_t wifi_coex_start_connect(void);        // no-op: ESPHome connects
bool      wifi_coex_is_up(void);                // ESPHome's network has an IP
bool      ncp_host_peer_allowed(uint32_t ipv4_be);  // allowed_ips filter for the TCP server

#ifdef __cplusplus
}
#endif
