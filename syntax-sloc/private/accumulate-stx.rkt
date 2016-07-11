#lang typed/racket/base

(provide accumulate/stx accumulate/stx*)

(require racket/list)

(module+ test
  (provide test-with-accumulate/stx-definition)
  (require typed/rackunit typed/syntax/stx))

(: accumulate/stx* : (∀ (A) Any [A (Syntaxof Any) -> A] A -> A))
;; This always recurs into sub-expressions after add-stx has been called.
(define (accumulate/stx* stx add-stx acc)
  (: add-stx* : A (Syntaxof Any) -> A)
  (define (add-stx* acc stx)
    (accumulate/stx (syntax-e stx) add-stx* (add-stx acc stx)))
  (accumulate/stx stx add-stx* acc))

(: accumulate/stx : (∀ (A) Any [A (Syntaxof Any) -> A] A -> A))
;; This never recurs into sub-expressions after add-stx has been called,
;; but add-stx can decide to recur instead.
(define (accumulate/stx stx add-stx acc)
  (cond [(syntax? stx)
         ; this is the only case that adds stx to acc
         (add-stx acc stx)]
        [(empty? stx)
         acc]
        [(cons? stx)
         ; this adds everything in the car, then everything in the cdr
         (accumulate/stx (cdr stx) add-stx
           (accumulate/stx (car stx) add-stx acc))]
        [(box? stx)
         ; this adds everything in the contents of the box
         (accumulate/stx (unbox stx) add-stx acc)]
        [(vector? stx)
         ; or vector
         (for/fold ([acc acc])
                   ([val (in-vector stx)])
           (accumulate/stx val add-stx acc))]
        [(hash? stx)
         ; or hash
         (for/fold ([acc acc])
                   ([(key val) (in-hash stx)])
           (accumulate/stx val add-stx
             (accumulate/stx key add-stx acc)))]
        [(struct? stx)
         ; or non-opaque struct, including prefab structs,
         (accumulate/stx (struct->vector stx) add-stx acc)]
        [else
         ; otherwise give up.
         acc]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(module+ test
  (define accumulate/stx*-definition
    #'(define (accumulate/stx* stx add-stx acc)
        (: add-stx* : A (Syntaxof Any) -> A)
        (define (add-stx* acc stx)
          (accumulate/stx (syntax-e stx) add-stx* (add-stx acc stx)))
        (accumulate/stx stx add-stx* acc)))

  (define accumulate/stx-definition
    #'(define (accumulate/stx stx add-stx acc)
        (cond [(syntax? stx)
               ; this is the only case that adds stx to acc
               (add-stx acc stx)]
              [(empty? stx)
               acc]
              [(cons? stx)
               ; this adds everything in the car, then everything in the cdr
               (accumulate/stx (cdr stx) add-stx
                 (accumulate/stx (car stx) add-stx acc))]
              [(box? stx)
               ; this adds everything in the contents of the box
               (accumulate/stx (unbox stx) add-stx acc)]
              [(vector? stx)
               ; or vector
               (for/fold ([acc acc])
                         ([val (in-vector stx)])
                 (accumulate/stx val add-stx acc))]
              [(hash? stx)
               ; or hash
               (for/fold ([acc acc])
                         ([(key val) (in-hash stx)])
                 (accumulate/stx val add-stx
                   (accumulate/stx key add-stx acc)))]
              [(struct? stx)
               ; or non-opaque struct, including prefab structs,
               (accumulate/stx (struct->vector stx) add-stx acc)]
              [else
               ; otherwise give up.
               acc])))

  (: test-with-accumulate/stx-definition :
     [(Syntaxof Any) -> Natural]
     [(Syntaxof Any) [(Syntaxof Any) -> Boolean] -> Natural]
     -> Void)
  (define (test-with-accumulate/stx-definition syntax-sloc syntax-sloc/filter)
    (test-case "test-with-accumulate/stx-definition"
      (test-case "syntax-sloc"
        (check-equal? (syntax-sloc accumulate/stx*-definition) 5)
        (check-equal? (syntax-sloc accumulate/stx-definition) 23)
        ))
    (test-case "syntax-sloc/filter"
      (: for/fold-form? : (Syntaxof Any) -> Boolean)
      (define (for/fold-form? stx)
        (and
         (stx-pair? stx)
         (let ([a (stx-car stx)])
           (and (identifier? a)
                (free-identifier=? a #'for/fold)))))
      (check-equal? (syntax-sloc/filter accumulate/stx-definition for/fold-form?) 7)
      )
    (void))

  )
