# esphome-zboss-ncp

An ESPHome external component that turns an **ESP32-C6** (or C5) into a
**Zigbee coordinator** for Zigbee2MQTT and ZHA, using the ZBOSS NCP firmware
from [tostmann/esp-coordinator](https://github.com/tostmann/esp-coordinator)
(MIT, after andryblack/esp-coordinator).

The coordinator code runs as an ESP-IDF component (`components/zboss_ncp/zboss_ncp_idf`),
with only small changes. ESPHome provides everything around it: WiFi or
Ethernet, **WireGuard**, OTA, logging, the native API and diagnostic sensors.
The host connects to the NCP over TCP.

> **Status: proof of concept.** Builds with ESPHome 2026.10.2 (ESP-IDF 5.5.6,
> esp-zigbee-lib 1.6) for WiFi and for W5500 Ethernet. Runs on an ESP32-C6 over
> WiFi with Zigbee2MQTT (`adapter: zboss`, TCP): the network taken over from a
> USB stick (`tools/migrate_stick.py`), devices switch. Not yet tested:
> WireGuard, Ethernet, UART, ZHA, network backup/restore.

## Use

```yaml
external_components:
  - source: github://whulshof/esphome-zboss-ncp@main   # or type: local
    components: [zboss_ncp]

esp32:
  variant: esp32c6
  flash_size: 4MB
  framework:
    type: esp-idf

zboss_ncp:
  port: 6638                 # NCP over TCP
  allowed_ips:               # optional: only these may connect
    - 10.66.0.0/24           # e.g. the WireGuard network
  # uart:                    # optional extra host link on UART1
  #   tx_pin: GPIO22
  #   rx_pin: GPIO23
  # external_antenna: true   # Seeed XIAO ESP32-C6: U.FL antenna
  channel:          { name: Zigbee channel }
  pan_id:           { name: Zigbee PAN ID }
  extended_pan_id:  { name: Zigbee extended PAN ID }
  firmware_version: { name: NCP firmware }
  host_connected:   { name: Zigbee host connected }
  network_lost:     { name: Zigbee network lost }
  safe_mode:        { name: NCP safe mode }
```

Full examples: [example/zigbee-coordinator.yaml](example/zigbee-coordinator.yaml)
(WiFi + WireGuard) and [example/zigbee-coordinator-ethernet.yaml](example/zigbee-coordinator-ethernet.yaml)
(W5500 + WireGuard). Copy `example/secrets.example.yaml` to `secrets.yaml`.

```bash
esphome run example/zigbee-coordinator.yaml
```

### Host side

- **Zigbee2MQTT:** `serial: { port: "tcp://<ip>:6638", adapter: zboss }`. Over
  TCP upstream recommends its image `ghcr.io/tostmann/zigbee2mqtt-esp32`
  (longer timeouts); see upstream's ZIGBEE2MQTT.md.
- **ZHA:** radio type ZBOSS, `socket://<ip>:6638`, with
  [tostmann/zha-zboss-esp](https://github.com/tostmann/zha-zboss-esp).

## Design

| Topic | Upstream (wifi-coex branch) | Here |
| --- | --- | --- |
| Network | own WiFi STA, Improv, mDNS, info page | ESPHome (`wifi`, `ethernet`, `wireguard`); the NCP's `wifi_coex` calls go to `ncp_host.cpp` |
| Host link | TCP + UART1 (USB reserved for Improv) | TCP, optional UART1; USB-Serial/JTAG stays with ESPHome's logger |
| Who may connect | anyone who reaches the port | `allowed_ips` (checked on every accept) |
| NVS half of a network backup | partition `nvs` | own partition `zb_nvs` (24 KB). `nvs` is ESPHome's; a restore or factory reset never touches it, and backups stay 40 KB like on the USB stick |
| Start | `app_main()` | `zboss_ncp_main()` on its own task from the ESPHome component; a start failure is logged instead of `abort()` |
| WiFi power save | `WIFI_PS_NONE` | forced off via `wifi.force_power_save_off()`; `wifi: ap:` is refused (an AP cannot share the radio with Zigbee) |

Partitions added through ESPHome's `add_partition`: `zb_storage` (16 KB),
`zb_fct` (4 KB), `zb_nvs` (24 KB).

The component conflicts with ESPHome's own `zigbee` (end device/router,
esp-zigbee-lib 2.x) and `openthread`: one 802.15.4 stack per chip.

## Things to know

- **WiFi + Zigbee share one radio on the C6.** Upstream calls this
  experimental; Espressif rates "WiFi STA + always-on coordinator" as supported
  but unstable. Ethernet (W5500 on SPI) avoids it: the radio is then Zigbee-only.
- The NCP protocol has no authentication. Use `allowed_ips` and/or reach the
  port only through WireGuard.
- `NCP_RESET` from the host and a network restore reboot the whole device
  (as on the stick), so ESPHome restarts too.
- Upstream notes that backup/restore over TCP is degraded; the USB build is the
  reliable way to take a full backup.
- Heap: upstream found the WiFi build tight. ESPHome and WireGuard add to it;
  static RAM is 42% (WiFi) / 27% (Ethernet), runtime still to be measured.

## Tools

- `tools/migrate_stick.py`: take over the Zigbee network of a stick running
  tostmann/esp-coordinator (from an `esptool read_flash` dump of the same chip).
- `tools/ncp_probe.py <host>`: read-only check over TCP (version, joined,
  channel, PAN ids). It takes the NCP over from a connected Zigbee2MQTT/ZHA
  for a moment, so stop the host first.

## Updating from upstream

The firmware follows tostmann/esp-coordinator's `wifi-coex` branch (the one
with the TCP server; tostmann syncs `master` into it) through a vendor branch:

- branch `upstream` holds only upstream's files, in this repo's layout
  (`components/zboss_ncp/zboss_ncp_idf/`), without the parts ESPHome replaces
  (Improv, info page, `wifi_coex.cpp`, `netcfg.cpp`, build files);
- `main` = `upstream` + the changes marked `// esphome:` + files of its own
  (`ncp_host.cpp`, `netcfg.cpp` stub, `version.h`, `zboss_ncp_api.h`, the
  ESPHome component).

```bash
tools/sync_upstream.sh            # fetch wifi-coex, commit it on 'upstream', merge into the current branch
```

Git merges upstream's changes over ours; only lines both sides changed
conflict. The script also prints upstream's library versions and version
number (`idf_component.yml` and `version.h` are ours, update them by hand) and
the files upstream added. Then build an example to check.
