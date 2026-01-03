#lang racket/base

;; Simple test with file logging for debugging

(require racket/path
         racket/port
         "ffi-bridge.rkt")

(define log-port (open-output-file "/tmp/crt-test.log" #:exists 'replace))

(define (log msg)
  (displayln msg)
  (displayln msg log-port)
  (flush-output)
  (flush-output log-port))

(define (main)
  (log "=== Simple Passthrough Test (3 seconds) ===")

  (log "Step 1: Initializing...")
  (unless (crt-init)
    (log "ERROR: Failed to initialize")
    (exit 1))
  (log "Step 1: Done")

  (log "Step 2: Loading shader...")
  (define shader-path
    (build-path (current-directory) "generated" "passthrough.metal"))
  (log (format "Shader path: ~a" shader-path))

  (define shader-code
    (call-with-input-file shader-path port->string))

  (unless (crt-load-shader shader-code)
    (log "ERROR: Failed to load shader")
    (crt-shutdown)
    (exit 1))
  (log "Step 2: Done")

  (log "Step 3: Starting capture...")
  (unless (crt-start-capture 0)
    (log "ERROR: Failed to start capture")
    (crt-shutdown)
    (exit 1))
  (log "Step 3: Done")

  (log "Step 4: Showing overlay...")
  (crt-show-overlay)
  (log "Step 4: Done")

  (log "Running for 3 seconds...")
  (for ([i (in-range 3)])
    (sleep 1)
    (log (format "~a..." (- 3 i))))

  (log "Cleaning up...")
  (crt-stop-capture)
  (crt-hide-overlay)
  (crt-shutdown)
  (log "Done!")
  (close-output-port log-port))

(main)
