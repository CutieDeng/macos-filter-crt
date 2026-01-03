#lang racket/base

;; CRT Effect API - Simple interactive control
;; Usage:
;;   (require "crt-api.rkt")
;;   (start)  ; Start CRT effect
;;   (stop)   ; Stop CRT effect
;;   (toggle) ; Toggle on/off

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(provide start stop toggle status)

;; State
(define *running* #f)
(define *initialized* #f)

;; Initialize if needed
(define (ensure-init)
  (unless *initialized*
    (unless (crt-init)
      (error 'crt-api "Failed to initialize CRT system"))
    (set! *initialized* #t)
    (displayln "CRT system initialized.")))

;; Load the subtle CRT shader
(define (load-shader)
  (define shader-path
    (build-path (current-directory) "generated" "crt-subtle.metal"))
  (unless (file-exists? shader-path)
    (error 'crt-api "Shader file not found: ~a" shader-path))
  (define shader-code
    (call-with-input-file shader-path port->string))
  (unless (crt-load-shader shader-code)
    (error 'crt-api "Failed to load shader"))
  (displayln "Shader loaded."))

;; Start the CRT effect
(define (start)
  (cond
    [*running*
     (displayln "CRT effect is already running.")]
    [else
     (ensure-init)
     (load-shader)
     (unless (crt-start-capture 0)
       (error 'crt-api "Failed to start capture"))
     (crt-show-overlay)
     (set! *running* #t)
     (displayln "CRT effect started.")]))

;; Stop the CRT effect
(define (stop)
  (cond
    [(not *running*)
     (displayln "CRT effect is not running.")]
    [else
     (crt-stop-capture)
     (crt-hide-overlay)
     (set! *running* #f)
     (displayln "CRT effect stopped.")]))

;; Toggle the CRT effect
(define (toggle)
  (if *running*
      (stop)
      (start)))

;; Check status
(define (status)
  (displayln (if *running*
                 "CRT effect is running."
                 "CRT effect is stopped.")))

;; Print usage on load
(displayln "CRT Effect API loaded.")
(displayln "Commands: (start) (stop) (toggle) (status)")
