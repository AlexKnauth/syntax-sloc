#lang typed/racket/base

(provide pkg-sloc)

(require syntax-sloc/lang-file-sloc
         syntax-sloc/private/pkg-module-paths
         typed/syntax-sloc/read-lang-file)

(: pkg-sloc : String [#:use-file? (Path -> Boolean)] -> Natural)
(define (pkg-sloc name #:use-file? [use-file? (λ (path) #t)])
  (for/sum ([src (in-list (pkg-module-file-paths name))]
            #:when (and (file-exists? src)
                        (use-file? src)
                        (lang-file? src)))
    : Natural
    (lang-file-sloc src)))

