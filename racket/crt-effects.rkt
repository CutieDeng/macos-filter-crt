#lang racket/base

;; CRT Effects Definition
;; Defines the CRT filter shader using the Metal DSL

(require "metal-dsl.rkt")

(provide
 crt-shader
 crt-default-params
 generate-crt-shader)

;; ============================================================
;; Default Parameters
;; ============================================================

(define crt-default-params
  (hash
   'scanline-weight 6.0
   'scanline-gap 0.12
   'mask-brightness 0.75
   'mask-type 1        ; 1 = alternating, 2 = trinitron RGB
   'bloom-factor 1.5
   'input-gamma 2.4
   'output-gamma 2.2))

;; ============================================================
;; CRT Shader Definition
;; ============================================================

(define crt-uniforms
  (list
   (uniform "scanlineWeight" 'float 6.0)
   (uniform "scanlineGap" 'float 0.12)
   (uniform "maskBrightness" 'float 0.75)
   (uniform "maskType" 'int 1)
   (uniform "bloomFactor" 'float 1.5)
   (uniform "inputGamma" 'float 2.4)
   (uniform "outputGamma" 'float 2.2)
   (uniform "_padding" 'float 0.0)))  ; Alignment padding

;; Scanline effect function
(define scanline-function
  (shader-function
   "applyScanlines"
   '([color : float3]
     [uv : float2]
     [texHeight : float]
     [weight : float]
     [gap : float])
   'float3
   '((let* ([y (* (get-y uv) texHeight)]
            [scanlinePos (fract y)]
            [dist (- scanlinePos 0.5)]
            [scanlineFactor (max (- 1.0 (* dist dist weight)) gap)])
       (return (* color scanlineFactor))))))

;; Phosphor mask effect function
(define phosphor-function
  (shader-function
   "applyPhosphorMask"
   '([color : float3]
     [pos : uint2]
     [maskType : int]
     [brightness : float])
   'float3
   '((when (== maskType 1)
       ;; Green/Magenta alternating pattern
       (let* ([phase (& (get-x pos) 1)])
         (return (if (== phase 0)
                     (* color (float3 brightness 1.0 brightness))
                     (* color (float3 1.0 brightness 1.0))))))
     (when (== maskType 2)
       ;; Trinitron RGB stripe pattern
       (let* ([phase (% (get-x pos) 3)])
         (return (cond
                   [(== phase 0) (* color (float3 1.0 brightness brightness))]
                   [(== phase 1) (* color (float3 brightness 1.0 brightness))]
                   [else (* color (float3 brightness brightness 1.0))]))))
     ;; Default: no mask
     (return color))))

;; Bloom effect function
(define bloom-function
  (shader-function
   "applyBloom"
   '([color : float3]
     [factor : float])
   'float3
   '((let* ([luma (dot color (float3 0.299 0.587 0.114))]
            [boost (+ 1.0 (* (- factor 1.0) luma))])
       (return (* color boost))))))

;; Main CRT kernel
(define crt-kernel
  (compute-kernel
   "processCRT"
   '(;; Read input color
     (let* ([inputColor (texture-read inputTexture gid)]
            [color (get-rgb inputColor)]
            ;; Calculate UV coordinates
            [texWidth (texture-width inputTexture)]
            [texHeight (texture-height inputTexture)]
            [uv (/ (float2 gid) (float2 texWidth texHeight))])

       ;; Apply input gamma correction (linearize)
       (set! color (pow color (float3 (field uniforms inputGamma))))

       ;; Apply CRT effects
       (set! color (applyScanlines color uv texHeight
                                   (field uniforms scanlineWeight)
                                   (field uniforms scanlineGap)))

       (set! color (applyPhosphorMask color gid
                                      (field uniforms maskType)
                                      (field uniforms maskBrightness)))

       (set! color (applyBloom color (field uniforms bloomFactor)))

       ;; Apply output gamma correction
       (set! color (pow color (float3 (/ 1.0 (field uniforms outputGamma)))))

       ;; Clamp and write output
       (set! color (saturate color))
       (texture-write outputTexture gid (float4 (get-x color) (get-y color) (get-z color) 1.0))))))

;; Complete shader definition
(define crt-shader
  (define-shader 'crt-filter
    #:uniforms crt-uniforms
    #:functions (list scanline-function
                      phosphor-function
                      bloom-function)
    #:kernel crt-kernel))

;; Generate Metal code with custom parameters
(define (generate-crt-shader [params (hash)])
  (generate-metal-code crt-shader))

;; ============================================================
;; Test: Generate and print shader code
;; ============================================================

(module+ main
  (require racket/pretty)
  (displayln "=== Generated CRT Metal Shader ===\n")
  (displayln (generate-crt-shader)))
