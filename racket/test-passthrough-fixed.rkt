#lang racket/base

;; Test fixed passthrough with direct read

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (log msg)
  (displayln msg)
  (flush-output))

(define (main)
  (log "=== Fixed Passthrough Test (3 seconds) ===")
  (log "Using direct pixel read (no sampler)")
  (log "Should show screen content without shift/blur\n")

  (unless (crt-init)
    (log "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "passthrough-fixed.metal"))

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
  (log "Running for 3 seconds...")

  (for ([i (in-range 3)])
    (sleep 1)
    (log (format "~a..." (- 3 i))))

  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (log "Done!"))

(main)
