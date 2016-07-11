#lang typed/racket/base

;; DO NOT modify this file without also updating the SLOC count in:
;;  - the test at the bottom of this file
;;  - the example in the README.md file

(provide lang-file-sloc)

(require "syntax-sloc.rkt"
         typed/syntax-sloc/read-lang-file
         syntax-sloc/syntax-sloc)

(module+ test
  (require typed/rackunit
           racket/runtime-path))

(: lang-file-sloc : Path-String [#:use-stx? Stx-Pred] -> Natural)
(define (lang-file-sloc path-string #:use-stx? [use-stx? #f])
  (syntax-sloc (read-lang-file path-string) #:use-stx? use-stx?))

(module+ test
  (define-runtime-path this-file "lang-file-sloc.rkt")
  (check-equal? (lang-file-sloc this-file)
                14))

