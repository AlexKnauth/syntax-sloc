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
  (cond [(syntax? stx)
         ; this is the only case that adds to the set of lines
         (source-lines (syntax-e stx) (add-source-line lines (syntax-line stx)))]
        [(empty? stx)
         lines]
        [(cons? stx)
         ; this adds everything in the car, then everything in the cdr
         (source-lines (cdr stx) (source-lines (car stx) lines))]
        [(box? stx)
         ; this adds everything in the contents of the box
         (source-lines (unbox stx) lines)]
        [(vector? stx)
         ; or vector
         (for/fold ([lines lines])
                   ([val (in-vector stx)])
           (source-lines val lines))]
        [(hash? stx)
         ; or hash
         (for/fold ([lines lines])
                   ([(key val) (in-hash stx)])
           (source-lines val (source-lines key lines)))]
        [(struct? stx)
         ; or non-opaque struct, including prefab structs,
         (source-lines (struct->vector stx) lines)]
        [else
         ; otherwise give up.
         lines]))

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
                 #'(define (source-lines stx lines)
                     (cond [(syntax? stx)
                            ; this is the only case that adds to the set of lines
                            (source-lines (syntax-e stx) (add-source-line lines (syntax-line stx)))]
                           [(empty? stx)
                            lines]
                           [(cons? stx)
                            ; this adds everything in the car, then everything in the cdr
                            (source-lines (cdr stx) (source-lines (car stx) lines))]
                           [(box? stx)
                            ; this adds everything in the contents of the box
                            (source-lines (unbox stx) lines)]
                           [(vector? stx)
                            ; or vector
                            (for/fold ([lines lines])
                                      ([val (in-vector stx)])
                              (source-lines val lines))]
                           [(hash? stx)
                            ; or hash
                            (for/fold ([lines lines])
                                      ([(key val) (in-hash stx)])
                              (source-lines val (source-lines key lines)))]
                           [(struct? stx)
                            ; or non-opaque struct, including prefab structs,
                            (source-lines (struct->vector stx) lines)]
                           [else
                            ; otherwise give up.
                            lines])))
                21)

  )

