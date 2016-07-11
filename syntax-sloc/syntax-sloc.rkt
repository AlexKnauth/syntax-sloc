#lang typed/racket/base

(provide syntax-sloc)

(require racket/list
         racket/set)

(module+ test
  (require typed/rackunit typed/syntax/stx))

(: syntax-sloc : (Syntaxof Any) -> Natural)
(define (syntax-sloc stx)
  (set-count (source-lines stx (set))))

(: source-lines : Any (Setof Natural) -> (Setof Natural))
(define (source-lines stx lines)
  (accumulate/stx stx add-syntax-source-line lines))

(: add-syntax-source-line : (Setof Natural) (Syntaxof Any) -> (Setof Natural))
(define (add-syntax-source-line lines stx)
  (add-source-line lines (syntax-line stx)))

(: filter/stx : Any [(Syntaxof Any) -> Boolean] -> (Listof (Syntaxof Any)))
;; This doesn't recur into the sub-syntax objects of the ones that are added to the list.
(define (filter/stx stx include-stx?)
  (: add-stx : (Listof (Syntaxof Any)) (Syntaxof Any) -> (Listof (Syntaxof Any)))
  (define (add-stx acc stx)
    (if (include-stx? stx)
        (cons stx acc)
        (accumulate/stx/no-recur (syntax-e stx) add-stx acc)))
  (reverse
   (accumulate/stx/no-recur stx add-stx (list))))

(: accumulate/stx : (∀ (A) Any [A (Syntaxof Any) -> A] A -> A))
(define (accumulate/stx stx add-stx acc)
  (: add-stx* : A (Syntaxof Any) -> A)
  (define (add-stx* acc stx)
    (accumulate/stx/no-recur (syntax-e stx) add-stx* (add-stx acc stx)))
  (accumulate/stx/no-recur stx add-stx* acc))

(: accumulate/stx/no-recur : (∀ (A) Any [A (Syntaxof Any) -> A] A -> A))
(define (accumulate/stx/no-recur stx add-stx acc)
  (cond [(syntax? stx)
         ; this is the only case that adds stx to acc
         (add-stx acc stx)]
        [(empty? stx)
         acc]
        [(cons? stx)
         ; this adds everything in the car, then everything in the cdr
         (accumulate/stx/no-recur (cdr stx) add-stx
           (accumulate/stx/no-recur (car stx) add-stx acc))]
        [(box? stx)
         ; this adds everything in the contents of the box
         (accumulate/stx/no-recur (unbox stx) add-stx acc)]
        [(vector? stx)
         ; or vector
         (for/fold ([acc acc])
                   ([val (in-vector stx)])
           (accumulate/stx/no-recur val add-stx acc))]
        [(hash? stx)
         ; or hash
         (for/fold ([acc acc])
                   ([(key val) (in-hash stx)])
           (accumulate/stx/no-recur val add-stx
             (accumulate/stx/no-recur key add-stx acc)))]
        [(struct? stx)
         ; or non-opaque struct, including prefab structs,
         (accumulate/stx/no-recur (struct->vector stx) add-stx acc)]
        [else
         ; otherwise give up.
         acc]))

(: add-source-line : (Setof Natural) (U Natural False) -> (Setof Natural))
(define (add-source-line lines source-line)
  (cond [source-line (set-add lines source-line)]
        [else lines]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(module+ test

  (check-equal? (syntax-sloc #'(this is one line))
                1)

  (check-equal? (syntax-sloc #'(this
                                is
                                four
                                lines))
                4)

  (check-equal? (syntax-sloc #'(this
                                is
                                ;; even with a comment!
                                four
                                lines))
                4)

  (check-equal? (syntax-sloc #'(this
                                is
                                #;
                                (not how
                                     ever
                                     many
                                     lines
                                     this
                                     is
                                     but
                                     still)
                                four
                                lines))
                4)

  (check-equal? (syntax-sloc #'(define (syntax-sloc stx)
                                 (set-count (source-lines stx (set)))))
                2)

  (check-equal? (syntax-sloc
                 #'(define (accumulate/stx/no-recur stx add-stx acc)
                     (cond [(syntax? stx)
                            ; this is the only case that adds stx to acc
                            (add-stx acc stx)]
                           [(empty? stx)
                            acc]
                           [(cons? stx)
                            ; this adds everything in the car, then everything in the cdr
                            (accumulate/stx/no-recur (cdr stx) add-stx
                              (accumulate/stx/no-recur (car stx) add-stx acc))]
                           [(box? stx)
                            ; this adds everything in the contents of the box
                            (accumulate/stx/no-recur (unbox stx) add-stx acc)]
                           [(vector? stx)
                            ; or vector
                            (for/fold ([acc acc])
                                      ([val (in-vector stx)])
                              (accumulate/stx/no-recur val add-stx acc))]
                           [(hash? stx)
                            ; or hash
                            (for/fold ([acc acc])
                                      ([(key val) (in-hash stx)])
                              (accumulate/stx/no-recur val add-stx
                                (accumulate/stx/no-recur key add-stx acc)))]
                           [(struct? stx)
                            ; or non-opaque struct, including prefab structs,
                            (accumulate/stx/no-recur (struct->vector stx) add-stx acc)]
                           [else
                            ; otherwise give up.
                            acc])))
                23)

  (test-case "filter/stx"
    (define stx1 #'x)
    (define stx2 #'y)
    (define stx3 #'z)
    (define stx4 #`(#,stx1 #,stx2))
    (define stx5 #`(#,stx2 #,stx3))
    (define stx6 #`(#,stx4 #,stx5))
    (check-true (equal?
                 (filter/stx #`(#,stx1 (#,stx2) #,stx4 5 #,stx5)
                             identifier?)
                 (list stx1 stx2 stx1 stx2 stx2 stx3)))
    (check-true (equal?
                 (filter/stx (datum->syntax #f `#(,stx4 #(,stx5) ,stx6))
                             stx-list?)
                 (list stx4 stx5 stx6)))
    )

  )

