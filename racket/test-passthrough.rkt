#lang racket/base

;; Test passthrough shader - no effects, just verifies input->output works

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (main)
  (displayln "=== Passthrough Test (3 seconds) ===")
  (displayln "Should show screen exactly as-is (no effects)")
  (displayln "Red areas = coordinate bounds exceeded\n")

  (unless (crt-init)
    (displayln "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "passthrough.metal"))

  (define shader-code
    (call-with-input-file shader-path port->string))

  (unless (crt-load-shader shader-code)
    (displayln "ERROR: Failed to load shader")
    (crt-shutdown)
    (exit 1))

  (unless (crt-start-capture 0)
    (displayln "ERROR: Failed to start capture")
    (crt-shutdown)
    (exit 1))

  (crt-show-overlay)
  (displayln "Passthrough active...")

  (for ([i (in-range 3)])
    (sleep 1)
    (printf "~a... FPS: ~a\n" (- 3 i) (~r (crt-get-fps))))

  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (displayln "Done!"))

(define (~r num)
  (/ (round (* num 10)) 10.0))

(main)
