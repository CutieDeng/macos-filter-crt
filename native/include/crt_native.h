#ifndef CRT_NATIVE_H
#define CRT_NATIVE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialization and cleanup
bool crt_init(void);
void crt_shutdown(void);

// Screen capture control
bool crt_start_capture(uint32_t display_id);
void crt_stop_capture(void);

// Shader management
bool crt_load_shader(const char* metal_source);
bool crt_load_shader_from_file(const char* path);
bool crt_reload_shader(void);

// Uniform parameter updates
void crt_set_uniform_float(const char* name, float value);
void crt_set_uniform_int(const char* name, int value);

// Overlay window control
void crt_show_overlay(void);
void crt_hide_overlay(void);
void crt_toggle_overlay(void);
bool crt_is_overlay_visible(void);

// Status queries
bool crt_is_running(void);
float crt_get_fps(void);
float crt_get_latency_ms(void);

// Display info
uint32_t crt_get_main_display_id(void);
void crt_get_display_size(uint32_t display_id, uint32_t* width, uint32_t* height);

// Debug: show a simple test window (bright orange) for 5 seconds
void crt_test_window(void);

#ifdef __cplusplus
}
#endif

#endif // CRT_NATIVE_H
