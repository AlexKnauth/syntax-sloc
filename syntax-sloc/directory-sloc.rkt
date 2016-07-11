#lang typed/racket/base

(provide directory-sloc)

(require syntax-sloc/lang-file-sloc
         typed/syntax-sloc/read-lang-file
         syntax-sloc/syntax-sloc)

(: directory-sloc : Path-String [#:use-file? (Path -> Boolean)] [#:use-stx? Stx-Pred] -> Natural)
(define (directory-sloc dir #:use-file? [use-file? (λ (path) #t)] #:use-stx? [use-stx? #f])
  (for/sum ([src (in-directory dir)]
            #:when (and (file-exists? src) (use-file? src) (lang-file? src))) : Natural
    (lang-file-sloc src #:use-stx? use-stx?)))
