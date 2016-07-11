#lang typed/racket/base

;; DO NOT modify this file without also updating the SLOC count in:
;;  - the test at the bottom of this file
;;  - the example in the README.md file

(provide lang-file-sloc)

(require racket/set
         syntax-sloc/syntax-sloc
         typed/syntax-sloc/read-lang-file)

(module+ test
  (require typed/rackunit
           racket/runtime-path))

(: lang-file-sloc : Path-String [#:include-stx? Stx-Pred] -> Natural)
(define (lang-file-sloc path-string #:include-stx? [include-stx? #f])
  (define raw-stx (read-lang-file path-string))
  (define the-src (syntax-source raw-stx))
  (define exp-stx
    (parameterize ([current-namespace (make-base-namespace)])
      (expand raw-stx)))
  (define stx-to-count
    (if include-stx?
      (filter/stx exp-stx include-stx?)
      (list exp-stx)))
  (define (id/the-src? (stx : (Syntaxof Any))) : Boolean
    (and (identifier? stx) (equal? the-src (syntax-source stx))))
  (define lines-from-identifiers
    (for/fold : (Setof Natural)
              ([acc : (Setof Natural) (set)])
              ([stx (in-list stx-to-count)])
      (source-lines/filter stx id/the-src? acc)))
  (set-count lines-from-identifiers))

(module+ test
  (define-runtime-path this-file "lang-file-sloc.rkt")
  (check-equal? (lang-file-sloc this-file)
                29))

