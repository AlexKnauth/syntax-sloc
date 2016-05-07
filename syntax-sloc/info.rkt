#lang info

(define scribblings '(["scribblings/syntax-sloc.scrbl" ()]))

(define raco-commands
  '(["sloc" (submod syntax-sloc/raco-sloc main) "Count SLOC of a file or directory" #f]
    ))
