#lang racket/base

;; Test solid red shader - if this doesn't show, Metal layer is not visible

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (main)
  (displayln "=== Solid Red Test (10 seconds) ===")
  (displayln "Screen should turn COMPLETELY RED.\n")

  (unless (crt-init)
    (displayln "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "solid-red.metal"))

  (displayln (format "Loading shader from: ~a" shader-path))

  (define shader-code
    (call-with-input-file shader-path port->string))

  (unless (crt-load-shader shader-code)
    (displayln "ERROR: Failed to load shader")
    (crt-shutdown)
    (exit 1))

  (displayln "Shader loaded successfully!")

  (displayln "Starting screen capture...")
  (unless (crt-start-capture 0)
    (displayln "ERROR: Failed to start capture")
    (crt-shutdown)
    (exit 1))

  (displayln "Showing overlay...")
  (crt-show-overlay)

  (displayln "\n=== SCREEN SHOULD BE SOLID RED NOW ===\n")

  (for ([i (in-range 10)])
    (sleep 1)
    (printf "~a sec - FPS: ~a\n"
            (add1 i)
            (~r (crt-get-fps))))

  (displayln "\nShutting down...")
  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (displayln "Done!"))

(define (~r num)
  (/ (round (* num 10)) 10.0))

(main)
