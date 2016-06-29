#lang typed/racket/base

(provide syntax-sloc)

(require racket/list
         racket/set)

(module+ test
  (require typed/rackunit))

(: syntax-sloc : (Syntaxof Any) -> Natural)
(define (syntax-sloc stx)
  (set-count (source-lines stx (set))))

(: source-lines : Any (Setof Natural) -> (Setof Natural))
(define (source-lines stx lines)
  (accumulate/stx stx add-syntax-source-line lines))

(: add-syntax-source-line : (Setof Natural) (Syntaxof Any) -> (Setof Natural))
(define (add-syntax-source-line lines stx)
  (add-source-line lines (syntax-line stx)))

(: accumulate/stx : (∀ (A) Any [A (Syntaxof Any) -> A] A -> A))
(define (accumulate/stx stx add-stx acc)
  (cond [(syntax? stx)
         ; this is the only case that adds stx to acc
         (accumulate/stx (syntax-e stx) add-stx (add-stx acc stx))]
        [(empty? stx)
         acc]
        [(cons? stx)
         ; this adds everything in the car, then everything in the cdr
         (accumulate/stx (cdr stx) add-stx (accumulate/stx (car stx) add-stx acc))]
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
           (accumulate/stx val add-stx (accumulate/stx key add-stx acc)))]
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

  (check-equal? (syntax-sloc
                 #'(define (accumulate/stx stx add-stx acc)
                     (cond [(syntax? stx)
                            ; this is the only case that adds stx to acc
                            (accumulate/stx (syntax-e stx) add-stx (add-stx acc stx))]
                           [(empty? stx)
                            acc]
                           [(cons? stx)
                            ; this adds everything in the car, then everything in the cdr
                            (accumulate/stx (cdr stx) add-stx (accumulate/stx (car stx) add-stx acc))]
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
                              (accumulate/stx val add-stx (accumulate/stx key add-stx acc)))]
                           [(struct? stx)
                            ; or non-opaque struct, including prefab structs,
                            (accumulate/stx (struct->vector stx) add-stx acc)]
                           [else
                            ; otherwise give up.
                            acc])))
                21)

  )

