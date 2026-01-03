#lang racket/base

;; Test CRT effect with scanlines, phosphor mask, bloom

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (log msg)
  (displayln msg)
  (flush-output))

(define (main)
  (log "=== CRT Effect Test (5 seconds) ===")
  (log "Effects: scanlines, RGB phosphor mask, bloom, vignette")
  (log "No curvature (flat screen)\n")

  (unless (crt-init)
    (log "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "crt-effect.metal"))

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
  (log "CRT effect running...")

  (for ([i (in-range 5)])
    (sleep 1)
    (log (format "~a..." (- 5 i))))

  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (log "Done!"))

(main)
