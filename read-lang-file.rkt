#lang racket/base

(provide read-lang-file
         lang-file?)

(require syntax/modread)

(module+ test
  (require rackunit
           racket/runtime-path))

;; read-lang-file : Path-String -> Syntax
(define (read-lang-file path-string)
  (define port (open-input-file path-string))
  (port-count-lines! port)
  (begin0
    (with-module-reading-parameterization 
     (lambda () 
       (read-syntax (object-name port) port)))
    (close-input-port port)))

;; private value eq? to itself
(define read-language-fail (gensym 'read-language-fail))

;; lang-file? : Path-String -> Syntax
(define (lang-file? path-string)
  (cond
    [(file-exists? path-string)
     (define port (open-input-file path-string))
     (port-count-lines! port)
     (begin0
       (not (eq? (read-language port (λ () read-language-fail)) read-language-fail))
       (close-input-port port))]
    [else #f]))

(module+ test
  (define-runtime-path read-lang-file.rkt "read-lang-file.rkt")
  (define-runtime-path lang-file-sloc.rkt "lang-file-sloc.rkt")
  (define-runtime-path README.md "README.md")
  (define-runtime-path scribblings "scribblings")
  (check-true (lang-file? read-lang-file.rkt))
  (check-true (lang-file? lang-file-sloc.rkt))
  (check-false (lang-file? README.md))
  (check-false (lang-file? scribblings))
  (check-pred syntax? (read-lang-file read-lang-file.rkt))
  (check-pred syntax? (read-lang-file lang-file-sloc.rkt)))

