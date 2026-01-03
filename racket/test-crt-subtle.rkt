#lang racket/base

;; Test subtle CRT effect - gentle for daily use

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (log msg)
  (displayln msg)
  (flush-output))

(define (main)
  (log "=== Subtle CRT Effect Test (5 seconds) ===")
  (log "Effects: 240-line scanlines (subtle), light vignette, warm tint")
  (log "Designed for comfortable daily use\n")

  (unless (crt-init)
    (log "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "crt-subtle.metal"))

  (define shader-code
    (call-with-input-file shader-path port->string))

  (unless (crt-load-shader shader-code)
    (log "ERROR: Failed to load shader")
    (crt-shutdown)
    (exit 1))

  (unless (crt-start-capture 0)
    (log "ERROR: Failed to start capture")
    (crt-shutdown)
    (exit 1))

  (crt-show-overlay)
  (log "Subtle CRT effect running...")

  (for ([i (in-range 5)])
    (sleep 1)
    (log (format "~a..." (- 5 i))))

  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (log "Done!"))

(main)
