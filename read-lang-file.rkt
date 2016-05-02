#lang racket/base

(provide read-lang-file)

(require syntax/modread)

;; read-lang-file : Path-String -> Syntax
(define (read-lang-file path-string)
  (define port (open-input-file path-string))
  (port-count-lines! port)
  (begin0
    (with-module-reading-parameterization 
     (lambda () 
       (read-syntax (object-name port) port)))
    (close-input-port port)))

