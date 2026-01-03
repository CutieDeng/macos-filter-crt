#lang racket/base

;; Test color channel orders

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (log msg)
  (displayln msg)
  (flush-output))

(define (main)
  (log "=== Color Swizzle Test (5 seconds) ===")
  (log "Screen divided into 5 horizontal bands:")
  (log "  Band 1 (top): Original RGBA")
  (log "  Band 2: BGRA swapped to RGBA")
  (log "  Band 3: Red channel only (gray)")
  (log "  Band 4: Green channel only (gray)")
  (log "  Band 5 (bottom): Blue channel only (gray)")
  (log "")
  (log "Look for which band shows correct colors!\n")

  (unless (crt-init)
    (log "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "passthrough-swizzle.metal"))

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
