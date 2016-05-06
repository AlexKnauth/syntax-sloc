#lang info

(define collection "syntax-sloc")

(define deps
  '("base"
    ))

(define build-deps
  '("rackunit-lib"
    "scribble-lib"
    "scribble-code-examples"
    "racket-doc"
    ))

(define scribblings '(["scribblings/syntax-sloc.scrbl" ()]))

(define raco-commands '(
  ("sloc" (submod syntax-sloc/raco-sloc main) "Count SLOC of a file or directory" #f)
))
