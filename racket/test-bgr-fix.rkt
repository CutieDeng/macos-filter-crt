#lang racket/base

;; Test different channel orders

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (log msg)
  (displayln msg)
  (flush-output))

(define (main)
  (log "=== Channel Order Test (5 seconds) ===")
  (log "6 horizontal bands with yellow separators:")
  (log "  Band 0 (top): Original RGBA")
  (log "  Band 1: R<->B swapped (BGRA fix)")
  (log "  Band 2: ARGB interpretation")
  (log "  Band 3: R channel as grayscale")
  (log "  Band 4: G channel as grayscale")
  (log "  Band 5: B channel as grayscale")
  (log "")
  (log "Look for which band shows correct COLORS!\n")

  (unless (crt-init)
    (log "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "passthrough-bgr-fix.metal"))

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
