#lang typed/racket/base

;; This is a file with some code (C)
;; and some type annotations (T)
;; and some contracts (R)

#|  T   |# (: a Integer)
#| C    |# (define a 4)

#|  T   |# (: b (-> Integer Integer))
#| C    |# (define (b n)
#| C    |#   n)

#| CT   |# (define (c (x : String) (y : String)) : String
#| CT   |#   ((lambda ((z : String)) z) "hello"))

#| CT   |# (let* ([d : Integer 8]
#| C    |#        [e (for/fold :
#|  T   |#                     (Listof
#|      |#                       (
#|  T   |#                        Listof
#|  T   |#                         (Listof Integer)))
#| CT   |#                     ([acc : (Listof (Listof (Listof Integer))) '((()))])
#| C    |#                     ([e (in-range d)])
#| C    |#                  acc)])
#| C    |#   (void))

#| C    |# (module ctc racket/base
#| C    |#   (require racket/contract)
#| C    |#   (define (f x y)
#| C    |#     (+ x y 1))
#| C    |#   (provide
#| C  R |#     (contract-out
#| C  R |#       [f (->i ([x natural-number/c]
#|    R |#                [y (x) (>=/c x)])
#|    R |#               [result (x y) (and/c number? (>=/c (+ x y)))])])))

#| C    |# (module* untyped racket/base
#| C    |#   (define Symbol 2)
#| C    |#   (define (-> x y)
#| C    |#     (+ x y 1))
#| C    |#   (-> (-> Symbol Symbol) Symbol))
