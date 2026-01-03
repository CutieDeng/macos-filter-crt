#lang racket/base

;; Test script for red-tint shader - verifies rendering pipeline works

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (main)
  (displayln "=== Red Tint Shader Test ===")
  (displayln "This shader adds a VERY OBVIOUS red tint and dark scanlines.")
  (displayln "If you don't see red tint, the rendering pipeline has issues.\n")

  ;; Initialize
  (unless (crt-init)
    (displayln "ERROR: Failed to initialize")
    (exit 1))

  ;; Load the test-red shader
  (define shader-path
    (build-path (current-directory) "generated" "test-red.metal"))

  (displayln (format "Loading shader from: ~a" shader-path))

  (define shader-code
    (call-with-input-file shader-path port->string))

  (unless (crt-load-shader shader-code)
    (displayln "ERROR: Failed to load shader")
    (crt-shutdown)
    (exit 1))

  (displayln "Shader loaded successfully!")

  ;; Start capture
  (displayln "Starting screen capture...")
  (unless (crt-start-capture 0)
    (displayln "ERROR: Failed to start capture")
    (crt-shutdown)
    (exit 1))

  ;; Show overlay
  (displayln "Showing overlay...")
  (crt-show-overlay)

  ;; Wait and display status
  (displayln "\n=== RED TINT FILTER IS NOW ACTIVE ===")
  (displayln "You should see:")
  (displayln "  - Red tint on the entire screen")
  (displayln "  - Dark horizontal lines every 4 pixels")
  (displayln "\nIf you see NO effect, the overlay window is not rendering.")
  (displayln "Press Enter to exit...\n")

  (let loop ()
    (sleep 1)
    (printf "FPS: ~a  Latency: ~a ms\n"
            (~r (crt-get-fps))
            (~r (crt-get-latency-ms)))
    (when (not (char-ready?))
      (loop)))

  (read-line)

  ;; Cleanup
  (displayln "\nShutting down...")
  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (displayln "Done!"))

(define (~r num)
  (/ (round (* num 10)) 10.0))

(main)
