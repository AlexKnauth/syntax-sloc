#lang racket

#| C R |# (define/contract x
#| C   |#   integer?
#| C   |#   1)

#| C   |# (define (y z)
#| C   |#   z)

#| C   |# (provide
#|   R |#   (contract-out
#|   R |#     [y (-> natural-number/c natural-number/c)]))
