#lang racket/base

;; CRT 2.0 Effect API - Enhanced with flicker, noise, interlacing
;; Usage:
;;   (require "crt-api-2.0.rkt")
;;   (start)  ; Start CRT 2.0 effect
;;   (stop)   ; Stop CRT 2.0 effect

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(provide start stop toggle status)

;; State
(define *running* #f)
(define *initialized* #f)
(define *time-thread* #f)
(define *start-time* #f)

;; Initialize if needed
(define (ensure-init)
  (unless *initialized*
    (unless (crt-init)
      (error 'crt-api-2.0 "Failed to initialize CRT system"))
    (set! *initialized* #t)
    (displayln "CRT 2.0 system initialized.")))

;; Load the CRT 2.0 shader
(define (load-shader)
  (define shader-path
    (build-path (current-directory) "generated" "crt-2.0.metal"))
  (unless (file-exists? shader-path)
    (error 'crt-api-2.0 "Shader file not found: ~a" shader-path))
  (define shader-code
    (call-with-input-file shader-path port->string))
  (unless (crt-load-shader shader-code)
    (error 'crt-api-2.0 "Failed to load shader"))
  (displayln "CRT 2.0 shader loaded."))

;; Time update thread - updates the time uniform for animation
(define (start-time-thread)
  (set! *start-time* (current-inexact-milliseconds))
  (set! *time-thread*
        (thread
         (lambda ()
           (let loop ()
             (when *running*
               (define elapsed (/ (- (current-inexact-milliseconds) *start-time*) 1000.0))
               (crt-set-uniform-float "scanlineWeight" (exact->inexact elapsed))
               (sleep 0.016)  ; ~60fps update
               (loop)))))))

;; Stop time thread
(define (stop-time-thread)
  (when *time-thread*
    (set! *running* #f)
    (thread-wait *time-thread*)
    (set! *time-thread* #f)))

;; Start the CRT 2.0 effect
(define (start)
  (cond
    [*running*
     (displayln "CRT 2.0 effect is already running.")]
    [else
     (ensure-init)
     (load-shader)
     (unless (crt-start-capture 0)
       (error 'crt-api-2.0 "Failed to start capture"))
     (crt-show-overlay)
     (set! *running* #t)
     (start-time-thread)
     (displayln "CRT 2.0 effect started. (with flicker, noise, interlacing)")]))

;; Stop the CRT 2.0 effect
(define (stop)
  (cond
    [(not *running*)
     (displayln "CRT 2.0 effect is not running.")]
    [else
     (stop-time-thread)
     (crt-stop-capture)
     (crt-hide-overlay)
     (displayln "CRT 2.0 effect stopped.")]))

;; Toggle the CRT effect
(define (toggle)
  (if *running*
      (stop)
      (start)))

;; Check status
(define (status)
  (displayln (if *running*
                 "CRT 2.0 effect is running."
                 "CRT 2.0 effect is stopped.")))

;; Print usage on load
(displayln "CRT 2.0 Effect API loaded.")
(displayln "Enhanced effects: scanlines, flicker, noise, interlacing, color bleeding")
(displayln "Commands: (start) (stop) (toggle) (status)")
