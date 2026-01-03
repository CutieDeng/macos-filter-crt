#lang racket/base

;; Diagnostic test - shows colored corners to verify coordinate mapping
;; Red=top-left, Green=top-right, Blue=bottom-left, Yellow=bottom-right
;; White border around whole screen
;; Cyan center = input/output size mismatch

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define (main)
  (displayln "=== Diagnostic Test (3 seconds) ===")
  (displayln "Expected:")
  (displayln "  - Red corner: top-left")
  (displayln "  - Green corner: top-right")
  (displayln "  - Blue corner: bottom-left")
  (displayln "  - Yellow corner: bottom-right")
  (displayln "  - White border around entire screen")
  (displayln "  - Cyan center = size mismatch warning")
  (displayln "  - Screen content in the middle\n")

  (unless (crt-init)
    (displayln "ERROR: Failed to initialize")
    (exit 1))

  (define shader-path
    (build-path (current-directory) "generated" "diagnostic.metal"))

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
  (displayln "Diagnostic running...")

  (for ([i (in-range 3)])
    (sleep 1)
    (printf "~a...\n" (- 3 i)))

  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (displayln "Done!"))

(main)
