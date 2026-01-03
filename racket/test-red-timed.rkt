#lang racket/base

;; Timed test script for red-tint shader - runs for 15 seconds

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (main)
  (displayln "=== Red Tint Shader Test (15 seconds) ===")
  (displayln "This shader adds a VERY OBVIOUS red tint and dark scanlines.\n")

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
  (displayln "Running for 15 seconds...")
  (displayln "You should see red tint and horizontal dark lines.\n")

  ;; Run for 15 seconds
  (for ([i (in-range 15)])
    (sleep 1)
    (printf "~a sec - FPS: ~a  Latency: ~a ms\n"
            (add1 i)
            (~r (crt-get-fps))
            (~r (crt-get-latency-ms))))

  ;; Cleanup
  (displayln "\nShutting down...")
  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (displayln "Done!"))

(define (~r num)
  (/ (round (* num 10)) 10.0))

(main)
