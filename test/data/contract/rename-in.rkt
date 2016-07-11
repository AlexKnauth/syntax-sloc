#lang racket/base
#| C    |# (require
#|      |#   (prefix-in c: (only-in racket/contract ->))
#|      |#   (rename-in racket/contract [natural-number/c nat/c]))

#| C    |# (define nat?
#|    R |#   nat/c)
#| C    |# (define/contract foo
#|    R |#   (c:->
#|    R |#     nat/c
#|    R |#     nat/c)
#| C    |#   (lambda (x) 3))

