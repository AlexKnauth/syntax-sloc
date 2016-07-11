#lang racket/base

#| C    |# (module a
#| C    |#   (require racket/contract)
#| C  R |#   (define/contract x integer? 2))
#|      |#
#| C    |# (module* b
#| C    |#   (require racket/contract)
#| C  R |#   (define/contract y integer? 3))
