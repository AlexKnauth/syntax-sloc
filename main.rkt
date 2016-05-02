#lang racket/base

(provide syntax-sloc)

(require racket/list
         racket/set)

;; syntax-sloc : Syntax -> Natural
(define (syntax-sloc stx)
  (set-count (source-lines stx (set))))

;; source-lines : Any (Setof Natural) -> (Setof Natural)
(define (source-lines stx lines)
  (cond [(syntax? stx)
         (source-lines (syntax-e stx) (set-add lines (syntax-line stx)))]
        [(empty? stx)
         lines]
        [(cons? stx)
         (source-lines (cdr stx) (source-lines (car stx) lines))]
        [(box? stx)
         (source-lines (unbox stx) lines)]
        [(vector? stx)
         (for/fold ([lines lines])
                   ([val (in-vector stx)])
           (source-lines val lines))]
        [(hash? stx)
         (for/fold ([lines lines])
                   ([(key val) (in-hash stx)])
           (source-lines val (source-lines key lines)))]
        [(struct? stx)
         (source-lines (struct->vector stx) lines)]
        [else
         lines]))

