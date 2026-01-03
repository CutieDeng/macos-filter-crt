#lang racket/base

;; Metal Shader DSL for Racket
;; Provides metaprogramming capabilities to generate Metal Shading Language code

(require racket/match
         racket/string
         racket/list
         racket/format)

(provide
 ;; Shader definition
 define-shader
 shader-definition
 shader-definition?
 shader-definition-name
 shader-definition-uniforms
 shader-definition-functions
 shader-definition-kernel

 ;; Uniform definition
 uniform
 uniform?
 uniform-name
 uniform-type
 uniform-default

 ;; Function definition
 shader-function
 shader-function?
 shader-function-name
 shader-function-params
 shader-function-return-type
 shader-function-body

 ;; Kernel definition
 compute-kernel
 compute-kernel?
 compute-kernel-name
 compute-kernel-body

 ;; Code generation
 generate-metal-code
 generate-uniforms-struct

 ;; Type mappings
 metal-type->string)

;; ============================================================
;; Data Structures
;; ============================================================

(struct shader-definition (name uniforms functions kernel) #:transparent)
(struct uniform (name type default) #:transparent)
(struct shader-function (name params return-type body) #:transparent)
(struct compute-kernel (name body) #:transparent)

;; ============================================================
;; Type Mapping
;; ============================================================

(define (metal-type->string type)
  (match type
    ['float "float"]
    ['float2 "float2"]
    ['float3 "float3"]
    ['float4 "float4"]
    ['half "half"]
    ['half2 "half2"]
    ['half3 "half3"]
    ['half4 "half4"]
    ['int "int"]
    ['int2 "int2"]
    ['uint "uint"]
    ['uint2 "uint2"]
    ['bool "bool"]
    ['texture2d-read "texture2d<float, access::read>"]
    ['texture2d-write "texture2d<float, access::write>"]
    [else (symbol->string type)]))

;; ============================================================
;; DSL Macros and Builders
;; ============================================================

;; Create a shader definition
(define (define-shader name
          #:uniforms [uniforms '()]
          #:functions [functions '()]
          #:kernel kernel)
  (shader-definition name uniforms functions kernel))

;; ============================================================
;; Expression to Metal Code
;; ============================================================

(define (expr->metal expr [indent 0])
  (define pad (make-string indent #\space))
  (match expr
    ;; Literals
    [(? number? n) (format "~a" n)]
    [(? symbol? s) (symbol->string s)]
    [(? string? s) s]

    ;; Variable declaration
    [`(let ([,var ,val]) ,body ...)
     (string-append
      (format "~a~a = ~a;\n" pad (symbol->string var) (expr->metal val))
      (string-join (map (λ (b) (expr->metal b indent)) body) ""))]

    ;; Let* - sequential bindings
    [`(let* () ,body ...)
     (string-join (map (λ (b) (expr->metal b indent)) body) "")]

    [`(let* ([,var ,val] ,rest ...) ,body ...)
     (string-append
      (format "~aauto ~a = ~a;\n" pad (symbol->string var) (expr->metal val))
      (expr->metal `(let* ,rest ,@body) indent))]

    ;; Typed variable declaration
    [`(define-var ,type ,var ,val)
     (format "~a~a ~a = ~a;\n" pad
             (metal-type->string type)
             (symbol->string var)
             (expr->metal val))]

    ;; Assignment
    [`(set! ,var ,val)
     (format "~a~a = ~a;\n" pad (symbol->string var) (expr->metal val))]

    ;; If expression
    [`(if ,cond ,then ,else)
     (format "(~a ? ~a : ~a)"
             (expr->metal cond)
             (expr->metal then)
             (expr->metal else))]

    ;; Cond expression
    [`(cond [,test ,result] ,rest ...)
     (if (null? rest)
         (expr->metal result)
         (format "(~a ? ~a : ~a)"
                 (expr->metal test)
                 (expr->metal result)
                 (expr->metal `(cond ,@rest))))]

    ;; When (if without else)
    [`(when ,cond ,body ...)
     (string-append
      (format "~aif (~a) {\n" pad (expr->metal cond))
      (string-join (map (λ (b) (expr->metal b (+ indent 4))) body) "")
      (format "~a}\n" pad))]

    ;; Return statement
    [`(return ,val)
     (format "~areturn ~a;\n" pad (expr->metal val))]

    ;; Binary operators (with variadic support for + and *)
    [`(+ ,a) (expr->metal a)]
    [`(+ ,a ,b) (format "(~a + ~a)" (expr->metal a) (expr->metal b))]
    [`(+ ,a ,b ,rest ...) (expr->metal `(+ (+ ,a ,b) ,@rest))]
    [`(- ,a ,b) (format "(~a - ~a)" (expr->metal a) (expr->metal b))]
    [`(* ,a) (expr->metal a)]
    [`(* ,a ,b) (format "(~a * ~a)" (expr->metal a) (expr->metal b))]
    [`(* ,a ,b ,rest ...) (expr->metal `(* (* ,a ,b) ,@rest))]
    [`(/ ,a ,b) (format "(~a / ~a)" (expr->metal a) (expr->metal b))]
    [`(< ,a ,b) (format "(~a < ~a)" (expr->metal a) (expr->metal b))]
    [`(> ,a ,b) (format "(~a > ~a)" (expr->metal a) (expr->metal b))]
    [`(<= ,a ,b) (format "(~a <= ~a)" (expr->metal a) (expr->metal b))]
    [`(>= ,a ,b) (format "(~a >= ~a)" (expr->metal a) (expr->metal b))]
    [`(== ,a ,b) (format "(~a == ~a)" (expr->metal a) (expr->metal b))]
    [`(!= ,a ,b) (format "(~a != ~a)" (expr->metal a) (expr->metal b))]
    [`(&& ,a ,b) (format "(~a && ~a)" (expr->metal a) (expr->metal b))]
    [`(|| ,a ,b) (format "(~a || ~a)" (expr->metal a) (expr->metal b))]
    [`(% ,a ,b) (format "(~a % ~a)" (expr->metal a) (expr->metal b))]
    [`(& ,a ,b) (format "(~a & ~a)" (expr->metal a) (expr->metal b))]

    ;; Unary operators
    [`(- ,a) (format "(-~a)" (expr->metal a))]
    [`(! ,a) (format "(!~a)" (expr->metal a))]

    ;; Type constructors
    [`(float2 ,x ,y) (format "float2(~a, ~a)" (expr->metal x) (expr->metal y))]
    [`(float3 ,x ,y ,z) (format "float3(~a, ~a, ~a)" (expr->metal x) (expr->metal y) (expr->metal z))]
    [`(float4 ,x ,y ,z ,w) (format "float4(~a, ~a, ~a, ~a)" (expr->metal x) (expr->metal y) (expr->metal z) (expr->metal w))]
    [`(float3 ,v) (format "float3(~a)" (expr->metal v))]
    [`(float2 ,v) (format "float2(~a)" (expr->metal v))]

    ;; Vector component access (alternative syntax for Racket compatibility)
    [`(get-x ,v) (format "~a.x" (expr->metal v))]
    [`(get-y ,v) (format "~a.y" (expr->metal v))]
    [`(get-z ,v) (format "~a.z" (expr->metal v))]
    [`(get-w ,v) (format "~a.w" (expr->metal v))]
    [`(get-xy ,v) (format "~a.xy" (expr->metal v))]
    [`(get-xyz ,v) (format "~a.xyz" (expr->metal v))]
    [`(get-rgb ,v) (format "~a.rgb" (expr->metal v))]

    ;; Struct field access
    [`(field ,obj ,fld) (format "~a.~a" (expr->metal obj) (symbol->string fld))]

    ;; Legacy vector component access
    [`(.x ,v) (format "~a.x" (expr->metal v))]
    [`(.y ,v) (format "~a.y" (expr->metal v))]
    [`(.z ,v) (format "~a.z" (expr->metal v))]
    [`(.w ,v) (format "~a.w" (expr->metal v))]
    [`(.xy ,v) (format "~a.xy" (expr->metal v))]
    [`(.xyz ,v) (format "~a.xyz" (expr->metal v))]
    [`(.rgb ,v) (format "~a.rgb" (expr->metal v))]

    ;; Built-in functions
    [`(pow ,a ,b) (format "pow(~a, ~a)" (expr->metal a) (expr->metal b))]
    [`(sqrt ,a) (format "sqrt(~a)" (expr->metal a))]
    [`(abs ,a) (format "abs(~a)" (expr->metal a))]
    [`(min ,a ,b) (format "min(~a, ~a)" (expr->metal a) (expr->metal b))]
    [`(max ,a ,b) (format "max(~a, ~a)" (expr->metal a) (expr->metal b))]
    [`(clamp ,v ,lo ,hi) (format "clamp(~a, ~a, ~a)" (expr->metal v) (expr->metal lo) (expr->metal hi))]
    [`(mix ,a ,b ,t) (format "mix(~a, ~a, ~a)" (expr->metal a) (expr->metal b) (expr->metal t))]
    [`(fract ,a) (format "fract(~a)" (expr->metal a))]
    [`(floor ,a) (format "floor(~a)" (expr->metal a))]
    [`(ceil ,a) (format "ceil(~a)" (expr->metal a))]
    [`(sin ,a) (format "sin(~a)" (expr->metal a))]
    [`(cos ,a) (format "cos(~a)" (expr->metal a))]
    [`(dot ,a ,b) (format "dot(~a, ~a)" (expr->metal a) (expr->metal b))]
    [`(saturate ,a) (format "saturate(~a)" (expr->metal a))]

    ;; Texture operations
    [`(texture-read ,tex ,coord)
     (format "~a.read(~a)" (expr->metal tex) (expr->metal coord))]
    [`(texture-write ,tex ,coord ,val)
     (format "~a~a.write(~a, ~a);\n" pad (expr->metal tex) (expr->metal val) (expr->metal coord))]
    [`(texture-width ,tex)
     (format "~a.get_width()" (expr->metal tex))]
    [`(texture-height ,tex)
     (format "~a.get_height()" (expr->metal tex))]

    ;; Generic function call
    [`(,func ,args ...)
     (format "~a(~a)"
             (if (symbol? func) (symbol->string func) (expr->metal func))
             (string-join (map expr->metal args) ", "))]

    [else (error 'expr->metal "Unknown expression: ~a" expr)]))

;; ============================================================
;; Code Generation
;; ============================================================

(define (generate-header)
  #<<METAL
#include <metal_stdlib>
using namespace metal;

METAL
  )

(define (generate-uniforms-struct uniforms)
  (if (null? uniforms)
      ""
      (string-append
       "struct Uniforms {\n"
       (string-join
        (for/list ([u uniforms])
          (format "    ~a ~a;\n"
                  (metal-type->string (uniform-type u))
                  (uniform-name u)))
        "")
       "};\n\n")))

(define (generate-function func)
  (match-define (shader-function name params return-type body) func)
  (string-append
   (format "~a ~a("
           (metal-type->string return-type)
           name)
   (string-join
    (for/list ([p params])
      (match p
        [`(,pname : ,ptype) (format "~a ~a" (metal-type->string ptype) pname)]
        [`(,pname ,ptype) (format "~a ~a" (metal-type->string ptype) pname)]))
    ", ")
   ") {\n"
   (string-join (map (λ (b) (expr->metal b 4)) body) "")
   "}\n\n"))

(define (generate-kernel kernel has-uniforms)
  (match-define (compute-kernel name body) kernel)
  (string-append
   "kernel void " name "(\n"
   "    texture2d<float, access::read> inputTexture [[texture(0)]],\n"
   "    texture2d<float, access::write> outputTexture [[texture(1)]],\n"
   (if has-uniforms
       "    constant Uniforms& uniforms [[buffer(0)]],\n"
       "")
   "    uint2 gid [[thread_position_in_grid]])\n"
   "{\n"
   "    // Bounds check\n"
   "    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {\n"
   "        return;\n"
   "    }\n\n"
   (string-join (map (λ (b) (expr->metal b 4)) body) "")
   "}\n"))

(define (generate-metal-code shader)
  (match-define (shader-definition name uniforms functions kernel) shader)
  (string-append
   "// Generated by Racket Metal DSL\n"
   "// Shader: " (symbol->string name) "\n\n"
   (generate-header)
   (generate-uniforms-struct uniforms)
   (string-join (map generate-function functions) "")
   (generate-kernel kernel (not (null? uniforms)))))
