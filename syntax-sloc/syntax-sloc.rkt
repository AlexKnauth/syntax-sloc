#lang typed/racket/base

(provide syntax-sloc)

(require racket/list
         racket/set)

(module+ test
  (require typed/rackunit typed/syntax/stx))

(: syntax-sloc : (Syntaxof Any) -> Natural)
(define (syntax-sloc stx)
  (set-count (source-lines stx (set))))

(: syntax-sloc/filter : (Syntaxof Any) [(Syntaxof Any) -> Boolean] -> Natural)
(define (syntax-sloc/filter stx include-stx?)
  (set-count (source-lines/filter stx include-stx? (set))))

(: source-lines : Any (Setof Natural) -> (Setof Natural))
(define (source-lines stx lines)
  (accumulate/stx* stx add-syntax-source-line lines))

(: source-lines/filter : Any [(Syntaxof Any) -> Boolean] (Setof Natural) -> (Setof Natural))
(define (source-lines/filter stx include-stx? lines)
  (for/fold ([lines lines])
            ([incl-stx (in-list (filter/stx stx include-stx?))])
    (source-lines incl-stx lines)))

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
        (accumulate/stx (syntax-e stx) add-stx acc)))
  (reverse
   (accumulate/stx stx add-stx (list))))

(: accumulate/stx* : (∀ (A) Any [A (Syntaxof Any) -> A] A -> A))
(define (accumulate/stx* stx add-stx acc)
  (: add-stx* : A (Syntaxof Any) -> A)
  (define (add-stx* acc stx)
    (accumulate/stx (syntax-e stx) add-stx* (add-stx acc stx)))
  (accumulate/stx stx add-stx* acc))

(: accumulate/stx : (∀ (A) Any [A (Syntaxof Any) -> A] A -> A))
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
  (check-equal? (syntax-sloc accumulate/stx-definition) 23)

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

    (: for/fold-form? : (Syntaxof Any) -> Boolean)
    (define (for/fold-form? stx)
      (and
       (stx-pair? stx)
       (let ([a (stx-car stx)])
         (and (identifier? a)
              (free-identifier=? a #'for/fold)))))
    (check-equal? (syntax-sloc/filter accumulate/stx-definition for/fold-form?) 7)
    )

  )

