#lang racket/base

;; Quick CRT test - runs for 3 seconds only

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (main)
  (displayln "=== CRT Filter Test (3 seconds) ===\n")

  (unless (crt-init)
    (displayln "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "crt-shader.metal"))

  (define shader-code
    (call-with-input-file shader-path port->string))

  (unless (crt-load-shader shader-code)
    (displayln "ERROR: Failed to load shader")
    (crt-shutdown)
    (exit 1))

  (displayln "Shader loaded!")

  (unless (crt-start-capture 0)
    (displayln "ERROR: Failed to start capture")
    (crt-shutdown)
    (exit 1))

  (crt-show-overlay)
  (displayln "CRT filter active for 3 seconds...")
  (displayln "You should see subtle scanlines and slight color effects.\n")

  ;; Run for exactly 3 seconds
  (for ([i (in-range 3)])
    (sleep 1)
    (printf "~a... FPS: ~a\n" (- 3 i) (~r (crt-get-fps))))

  (displayln "\nStopping...")
  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (displayln "Done!"))

(define (~r num)
  (/ (round (* num 10)) 10.0))

(main)
