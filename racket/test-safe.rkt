#lang racket/base

;; Safe test wrapper - always has timeout
;; Usage: racket test-safe.rkt <api-module> <seconds>
;; Example: racket test-safe.rkt crt-api.rkt 5

(require racket/cmdline
         racket/path)

(define api-module (make-parameter "crt-api.rkt"))
(define timeout-seconds (make-parameter 5))

(command-line
 #:args (module [seconds "5"])
 (api-module module)
 (timeout-seconds (string->number seconds)))

(displayln (format "=== Safe Test: ~a for ~a seconds ==="
                   (api-module) (timeout-seconds)))

(define api-path (build-path (current-directory) "racket" (api-module)))
(dynamic-require api-path #f)

(define start-proc (dynamic-require api-path 'start))
(define stop-proc (dynamic-require api-path 'stop))

(start-proc)
(sleep (timeout-seconds))
(stop-proc)
(displayln "Test completed safely.")
