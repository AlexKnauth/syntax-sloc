#lang racket/base

(provide directory-sloc)

(require syntax-sloc/lang-file-sloc syntax-sloc/read-lang-file)

;; directory-sloc : Path-String -> Natural
(define (directory-sloc dir)
  (for/sum ([src (in-directory dir)]
            #:when (lang-file? src))
    (lang-file-sloc src)))
