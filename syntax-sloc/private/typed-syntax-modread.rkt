#lang typed/racket/base

(provide with-module-reading-parameterization)

(require typed/racket/unsafe)

(unsafe-require/typed syntax/modread
                      [with-module-reading-parameterization
                       (All (A) (-> (-> A) A))])

