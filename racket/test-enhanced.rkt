#lang racket/base

;; Test script for enhanced CRT shader

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (main)
  (displayln "=== Enhanced CRT Filter Test ===\n")

  ;; Initialize
  (unless (crt-init)
    (displayln "ERROR: Failed to initialize")
    (exit 1))

  ;; Load the enhanced shader directly from file
  (define shader-path
    (build-path (current-directory) "generated" "crt-shader.metal"))

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
  (displayln "\nCRT filter is now active!")
  (displayln "You should see scanlines and RGB phosphor effect.")
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
