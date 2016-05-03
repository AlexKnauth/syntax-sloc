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

