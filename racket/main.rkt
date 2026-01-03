#lang racket/base

;; CRT Filter - Main Application Entry Point
;; Manages the CRT screen filter lifecycle using Racket

(require racket/cmdline
         racket/path
         racket/file
         racket/port
         racket/string
         racket/math
         racket/match
         "crt-effects.rkt"
         "ffi-bridge.rkt")

;; ============================================================
;; Configuration
;; ============================================================

(define current-config
  (make-parameter
   (hash
    'scanline-weight 6.0
    'scanline-gap 0.12
    'mask-brightness 0.75
    'mask-type 1
    'bloom-factor 1.5
    'input-gamma 2.4
    'output-gamma 2.2)))

(define generated-shader-path
  (make-parameter
   (build-path (current-directory) "generated" "crt-shader.metal")))

;; ============================================================
;; Shader Generation
;; ============================================================

(define (ensure-directory-exists path)
  (define dir (path-only path))
  (when (and dir (not (directory-exists? dir)))
    (make-directory* dir)))

(define (generate-and-save-shader!)
  (displayln "Generating CRT shader...")
  (define shader-code (generate-crt-shader))
  (define path (generated-shader-path))

  (ensure-directory-exists path)

  (call-with-output-file path
    (λ (out) (display shader-code out))
    #:exists 'replace)

  (printf "Shader saved to: ~a\n" path)
  shader-code)

;; ============================================================
;; Parameter Updates
;; ============================================================

(define (apply-config! config)
  (for ([(key value) (in-hash config)])
    (define name (symbol->string key))
    (cond
      [(member key '(mask-type))
       (crt-set-uniform-int name (exact-round value))]
      [else
       (crt-set-uniform-float name value)])))

(define (update-param! name value)
  (current-config (hash-set (current-config) name value))
  (define name-str (symbol->string name))
  (if (eq? name 'mask-type)
      (crt-set-uniform-int name-str (exact-round value))
      (crt-set-uniform-float name-str value))
  (printf "Updated ~a = ~a\n" name value))

;; ============================================================
;; Status Display
;; ============================================================

(define (print-status)
  (printf "\n=== CRT Filter Status ===\n")
  (printf "Running: ~a\n" (if (crt-running?) "Yes" "No"))
  (printf "Overlay: ~a\n" (if (crt-overlay-visible?) "Visible" "Hidden"))
  (printf "FPS: ~a\n" (~r (crt-get-fps) #:precision 1))
  (printf "Latency: ~a ms\n" (~r (crt-get-latency-ms) #:precision 2))
  (printf "=========================\n\n"))

(define (~r num #:precision [prec 2])
  (define factor (expt 10 prec))
  (/ (round (* num factor)) factor))

;; ============================================================
;; Interactive REPL
;; ============================================================

(define (print-help)
  (displayln "
CRT Filter Commands:
  help, h, ?     - Show this help
  status, s      - Show current status
  toggle, t      - Toggle overlay visibility
  show           - Show overlay
  hide           - Hide overlay
  reload, r      - Reload shader
  quit, q, exit  - Exit the application

Parameter Commands:
  set <param> <value>  - Set parameter value
  get <param>          - Get parameter value
  params               - List all parameters

Available Parameters:
  scanline-weight  - Scanline intensity (default: 6.0)
  scanline-gap     - Scanline gap brightness (default: 0.12)
  mask-brightness  - Phosphor mask brightness (default: 0.75)
  mask-type        - Mask type: 1=alternating, 2=trinitron (default: 1)
  bloom-factor     - Bloom intensity (default: 1.5)
  input-gamma      - Input gamma (default: 2.4)
  output-gamma     - Output gamma (default: 2.2)
"))

(define (parse-param-name str)
  (string->symbol (string-downcase str)))

(define (repl-loop)
  (display "crt> ")
  (flush-output)

  (define line (read-line))
  (when (eof-object? line)
    (displayln "\nExiting...")
    (exit))

  (define parts (string-split (string-trim line)))

  (match parts
    [(or '() '(""))
     (void)]

    [(or '("help") '("h") '("?"))
     (print-help)]

    [(or '("status") '("s"))
     (print-status)]

    [(or '("toggle") '("t"))
     (crt-toggle-overlay)
     (printf "Overlay: ~a\n" (if (crt-overlay-visible?) "Visible" "Hidden"))]

    ['("show")
     (crt-show-overlay)
     (displayln "Overlay shown")]

    ['("hide")
     (crt-hide-overlay)
     (displayln "Overlay hidden")]

    [(or '("reload") '("r"))
     (displayln "Reloading shader...")
     (define shader-code (generate-and-save-shader!))
     (if (crt-load-shader shader-code)
         (displayln "Shader reloaded successfully")
         (displayln "ERROR: Failed to reload shader"))]

    [(or '("quit") '("q") '("exit"))
     (displayln "Shutting down...")
     (crt-stop-capture)
     (crt-hide-overlay)
     (crt-shutdown)
     (displayln "Goodbye!")
     (exit)]

    ['("params")
     (displayln "Current parameters:")
     (for ([(k v) (in-hash (current-config))])
       (printf "  ~a = ~a\n" k v))]

    [(list "get" param-name)
     (define param (parse-param-name param-name))
     (define value (hash-ref (current-config) param #f))
     (if value
         (printf "~a = ~a\n" param value)
         (printf "Unknown parameter: ~a\n" param-name))]

    [(list "set" param-name value-str)
     (define param (parse-param-name param-name))
     (define value (string->number value-str))
     (if (and value (hash-has-key? (current-config) param))
         (update-param! param value)
         (printf "Invalid parameter or value: ~a ~a\n" param-name value-str))]

    [else
     (printf "Unknown command: ~a\nType 'help' for available commands.\n"
             (string-join parts " "))])

  (repl-loop))

;; ============================================================
;; Main Entry Point
;; ============================================================

(define (main)
  (displayln "====================================")
  (displayln "  CRT Screen Filter for macOS")
  (displayln "  Powered by Racket + Metal")
  (displayln "====================================\n")

  ;; Check library
  (unless (crt-library-loaded?)
    (displayln "ERROR: Native library not loaded!")
    (displayln "Please build the native library first:")
    (displayln "  cd native && make && make install")
    (exit 1))

  ;; Initialize
  (displayln "Initializing...")
  (unless (crt-init)
    (displayln "ERROR: Failed to initialize CRT filter!")
    (exit 1))

  ;; Generate and load shader
  (define shader-code (generate-and-save-shader!))
  (unless (crt-load-shader shader-code)
    (displayln "ERROR: Failed to load shader!")
    (crt-shutdown)
    (exit 1))

  ;; Apply default config
  (apply-config! (current-config))

  ;; Start capture
  (displayln "Starting screen capture...")
  (displayln "NOTE: You may need to grant 'Screen Recording' permission.")
  (unless (crt-start-capture 0)  ; 0 = main display
    (displayln "ERROR: Failed to start screen capture!")
    (displayln "Please check System Preferences > Privacy > Screen Recording")
    (crt-shutdown)
    (exit 1))

  ;; Show overlay
  (displayln "Showing overlay window...")
  (crt-show-overlay)

  ;; Wait a moment for everything to start
  (sleep 0.5)

  ;; Print initial status
  (print-status)

  ;; Enter interactive mode
  (displayln "Entering interactive mode. Type 'help' for commands.\n")
  (repl-loop))

;; ============================================================
;; Command Line Interface
;; ============================================================

(module+ main
  (command-line
   #:program "crt-filter"
   #:once-each
   [("-g" "--generate-only")
    "Only generate shader, don't run filter"
    (displayln "Generating shader only...")
    (generate-and-save-shader!)
    (exit 0)]
   [("-p" "--print-shader")
    "Print generated shader to stdout"
    (display (generate-crt-shader))
    (exit 0)]
   #:args ()
   (main)))
