#lang racket/base

;; Simple test: just show a basic window to verify visibility works

(require "ffi-bridge.rkt")

(displayln "=== Simple Window Visibility Test ===")
(displayln "This will show a small ORANGE window for 5 seconds.")
(displayln "If you can see it, the window system works.\n")

(displayln "Calling crt-test-window...")
(crt-test-window)
(displayln "Test complete!")
