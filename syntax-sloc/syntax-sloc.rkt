#lang typed/racket/base

(provide syntax-sloc syntax-sloc/filter)

(require racket/set
         "private/accumulate-stx.rkt"
         )

(define-type Syntax (Syntaxof Any))

(module+ test
  (require typed/rackunit typed/syntax/stx
           (submod "private/accumulate-stx.rkt" test)))

(: syntax-sloc : Syntax [#:count-line? [Syntax -> Boolean]] -> Natural)
(define (syntax-sloc stx #:count-line? [count-line? (λ (stx) #true)])
  (set-count (source-lines stx (set) #:count-line? count-line?)))

(: syntax-sloc/filter : Syntax [Syntax -> Boolean] [#:count-line? [Syntax -> Boolean]] -> Natural)
(define (syntax-sloc/filter stx include-stx? #:count-line? [count-line? (λ (stx) #true)])
  (set-count (source-lines/filter stx include-stx? (set) #:count-line? count-line?)))

(: source-lines : Any (Setof Natural) #:count-line? [Syntax -> Boolean] -> (Setof Natural))
(define (source-lines stx lines #:count-line? count-line?)
  (accumulate/stx* stx (add-syntax-source-line count-line?) lines))

(: source-lines/filter : Any [Syntax -> Boolean] (Setof Natural)
                         #:count-line? [Syntax -> Boolean]
                         -> (Setof Natural))
(define (source-lines/filter stx include-stx? lines #:count-line? count-line?)
  (for/fold ([lines lines])
            ([incl-stx (in-list (filter/stx stx include-stx?))])
    (source-lines incl-stx lines #:count-line? count-line?)))

(: add-syntax-source-line : [Syntax -> Boolean] -> [(Setof Natural) Syntax -> (Setof Natural)])
(define ((add-syntax-source-line count-line?) lines stx)
  (if (count-line? stx)
      (add-source-line lines (syntax-line stx))
      lines))

(: filter/stx : Any [Syntax -> Boolean] -> (Listof Syntax))
;; This doesn't recur into the sub-syntax objects of the ones that are added to the list.
(define (filter/stx stx include-stx?)
  (: add-stx : (Listof Syntax) Syntax -> (Listof Syntax))
  (define (add-stx acc stx)
    (if (include-stx? stx)
        (cons stx acc)
        (accumulate/stx (syntax-e stx) add-stx acc)))
  (reverse
   (accumulate/stx stx add-stx (list))))

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

  (test-with-accumulate/stx-definition syntax-sloc syntax-sloc/filter)

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

