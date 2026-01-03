#lang racket/base

;; Show individual color channels

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (log msg)
  (displayln msg)
  (flush-output))

(define (main)
  (log "=== Channel Test (5 seconds) ===")
  (log "Screen divided into 4 quadrants:")
  (log "  Top-left: RED channel only")
  (log "  Top-right: GREEN channel only")
  (log "  Bottom-left: BLUE channel only")
  (log "  Bottom-right: Original color")
  (log "")
  (log "White cross divides quadrants")
  (log "If all quadrants look the same gray = R=G=B (format issue)\n")

  (unless (crt-init)
    (log "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "channel-test.metal"))

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
  (log "Running for 5 seconds...")

  (for ([i (in-range 5)])
    (sleep 1)
    (log (format "~a..." (- 5 i))))

  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (log "Done!"))

(main)
