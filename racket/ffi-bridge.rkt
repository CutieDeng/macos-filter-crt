#lang racket/base

;; FFI Bridge to Native CRT Library
;; Provides Racket bindings for libcrt-native.dylib

(require ffi/unsafe
         ffi/unsafe/define
         racket/runtime-path)

(provide
 ;; Initialization
 crt-init
 crt-shutdown

 ;; Screen capture
 crt-start-capture
 crt-stop-capture

 ;; Shader management
 crt-load-shader
 crt-load-shader-from-file
 crt-reload-shader

 ;; Uniform updates
 crt-set-uniform-float
 crt-set-uniform-int

 ;; Overlay control
 crt-show-overlay
 crt-hide-overlay
 crt-toggle-overlay
 crt-overlay-visible?

 ;; Status
 crt-running?
 crt-get-fps
 crt-get-latency-ms

 ;; Display info
 crt-get-main-display-id
 crt-get-display-size

 ;; Debug
 crt-test-window

 ;; Library loading
 crt-library-loaded?)

;; ============================================================
;; Library Loading
;; ============================================================

(define-runtime-path lib-path "../libcrt-native.dylib")

(define libcrt
  (with-handlers ([exn:fail? (λ (e)
                               (eprintf "Warning: Failed to load libcrt-native.dylib: ~a\n"
                                        (exn-message e))
                               #f)])
    (ffi-lib lib-path)))

(define (crt-library-loaded?)
  (and libcrt #t))

;; ============================================================
;; FFI Definitions
;; ============================================================

(define-ffi-definer define-crt libcrt
  #:default-make-fail make-not-available)

;; Helper for unavailable functions
(define (make-not-available name)
  (λ args
    (error name "CRT native library not loaded")))

;; Initialization and cleanup
(define-crt crt_init (_fun -> _bool) #:c-id crt_init)
(define-crt crt_shutdown (_fun -> _void) #:c-id crt_shutdown)

;; Screen capture control
(define-crt crt_start_capture (_fun _uint32 -> _bool) #:c-id crt_start_capture)
(define-crt crt_stop_capture (_fun -> _void) #:c-id crt_stop_capture)

;; Shader management
(define-crt crt_load_shader (_fun _string -> _bool) #:c-id crt_load_shader)
(define-crt crt_load_shader_from_file (_fun _string -> _bool) #:c-id crt_load_shader_from_file)
(define-crt crt_reload_shader (_fun -> _bool) #:c-id crt_reload_shader)

;; Uniform parameter updates
(define-crt crt_set_uniform_float (_fun _string _float -> _void) #:c-id crt_set_uniform_float)
(define-crt crt_set_uniform_int (_fun _string _int -> _void) #:c-id crt_set_uniform_int)

;; Overlay window control
(define-crt crt_show_overlay (_fun -> _void) #:c-id crt_show_overlay)
(define-crt crt_hide_overlay (_fun -> _void) #:c-id crt_hide_overlay)
(define-crt crt_toggle_overlay (_fun -> _void) #:c-id crt_toggle_overlay)
(define-crt crt_is_overlay_visible (_fun -> _bool) #:c-id crt_is_overlay_visible)

;; Status queries
(define-crt crt_is_running (_fun -> _bool) #:c-id crt_is_running)
(define-crt crt_get_fps (_fun -> _float) #:c-id crt_get_fps)
(define-crt crt_get_latency_ms (_fun -> _float) #:c-id crt_get_latency_ms)

;; Display info
(define-crt crt_get_main_display_id (_fun -> _uint32) #:c-id crt_get_main_display_id)
(define-crt crt_get_display_size
  (_fun _uint32 (width : (_ptr o _uint32)) (height : (_ptr o _uint32))
        -> _void
        -> (values width height))
  #:c-id crt_get_display_size)

;; Debug test
(define-crt crt_test_window (_fun -> _void) #:c-id crt_test_window)

;; ============================================================
;; Racket-friendly Wrappers
;; ============================================================

(define (crt-init)
  (crt_init))

(define (crt-shutdown)
  (crt_shutdown))

(define (crt-start-capture [display-id 0])
  (crt_start_capture display-id))

(define (crt-stop-capture)
  (crt_stop_capture))

(define (crt-load-shader source)
  (crt_load_shader source))

(define (crt-load-shader-from-file path)
  (crt_load_shader_from_file (if (path? path)
                                  (path->string path)
                                  path)))

(define (crt-reload-shader)
  (crt_reload_shader))

(define (crt-set-uniform-float name value)
  (crt_set_uniform_float (if (symbol? name)
                              (symbol->string name)
                              name)
                          value))

(define (crt-set-uniform-int name value)
  (crt_set_uniform_int (if (symbol? name)
                            (symbol->string name)
                            name)
                        value))

(define (crt-show-overlay)
  (crt_show_overlay))

(define (crt-hide-overlay)
  (crt_hide_overlay))

(define (crt-toggle-overlay)
  (crt_toggle_overlay))

(define (crt-overlay-visible?)
  (crt_is_overlay_visible))

(define (crt-running?)
  (crt_is_running))

(define (crt-get-fps)
  (crt_get_fps))

(define (crt-get-latency-ms)
  (crt_get_latency_ms))

(define (crt-get-main-display-id)
  (crt_get_main_display_id))

(define (crt-get-display-size [display-id 0])
  (crt_get_display_size display-id))

(define (crt-test-window)
  (crt_test_window))
