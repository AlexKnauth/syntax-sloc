#lang typed/racket/base

;; DO NOT modify this file without also updating the SLOC count in:
;;  - the test at the bottom of this file
;;  - the example in the README.md file

(provide lang-file-sloc)

(require "syntax-sloc.rkt"
         "read-lang-file.rkt")

(module+ test
  (require typed/rackunit
           racket/runtime-path))

(: lang-file-sloc : Path-String -> Natural)
(define (lang-file-sloc path-string)
  (syntax-sloc (read-lang-file path-string)))

(module+ test
  (define-runtime-path this-file "lang-file-sloc.rkt")
  (check-equal? (lang-file-sloc this-file)
                14))

