# zboss_ncp: tostmann/esp-coordinator (ZBOSS NCP for Zigbee2MQTT/ZHA) as an
# ESP-IDF component, pulled into ESPHome by components/zboss_ncp/__init__.py.
set(priv_reqs nvs_flash esp_partition esp_timer esp_driver_gpio esp_driver_uart
              esp_driver_usb_serial_jtag lwip esp_system)
if(CONFIG_ESP_COEX_SW_COEXIST_ENABLE)
    list(APPEND priv_reqs esp_coex)
endif()

idf_component_register(SRC_DIRS "src"
                       INCLUDE_DIRS "src"
                       PRIV_REQUIRES ${priv_reqs})

# Upstream builds with -Werror off and some GNU extensions in C++.
target_compile_options(${COMPONENT_LIB} PRIVATE -Wno-unused-variable -Wno-unused-function
                       -Wno-missing-field-initializers)
