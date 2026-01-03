#lang racket/base

;; Debug UV coordinates - shows gradients and color channels

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (log msg)
  (displayln msg)
  (flush-output))

(define (main)
  (log "=== UV Debug Test (3 seconds) ===")
  (log "Expected:")
  (log "  - Top strip: red gradient (left=black, right=red)")
  (log "  - Left strip: green gradient (top=black, bottom=green)")
  (log "  - Top-left box: Blue if sizes match, Red/Green if mismatch")
  (log "  - Bottom-right 3 boxes: R, G, B channels separately")
  (log "  - Rest: screen content\n")

  (unless (crt-init)
    (log "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "debug-uv.metal"))

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
  (log "Debug running...")

  (for ([i (in-range 3)])
    (sleep 1)
    (log (format "~a..." (- 3 i))))

  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (log "Done!"))

(main)
