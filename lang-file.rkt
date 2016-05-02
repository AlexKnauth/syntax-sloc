#lang racket/base

(provide lang-file-sloc)

(require "main.rkt"
         "read-lang-file.rkt")

(module+ test
  (require rackunit
           syntax/location))

;; lang-file-sloc : Path-String -> Natural
(define (lang-file-sloc path-string)
  (syntax-sloc (read-lang-file path-string)))

(module+ test
  (check-equal? (lang-file-sloc (quote-source-file))
                11))

