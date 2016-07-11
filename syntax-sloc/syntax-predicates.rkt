#lang typed/racket/base

(provide module-path*->stx-predicate
         module-path->stx-predicate
         is-type-ann?
         is-contract?)

(require racket/set
         syntax-sloc/syntax-sloc)

(require/typed syntax/id-set
  (#:opaque Free-Id-Set immutable-free-id-set?)
  (immutable-free-id-set (->* [] [(Listof Identifier)] Free-Id-Set))
  (free-id-set-add (-> Free-Id-Set Identifier Free-Id-Set))
  (free-id-set->list (-> Free-Id-Set (Listof Identifier)))
  (free-id-set-member? (-> Free-Id-Set Identifier Boolean))
  (free-id-set-for-each (-> Free-Id-Set (-> Identifier Void) Void))
  (free-id-set-union (-> Free-Id-Set Free-Id-Set Free-Id-Set))
)

(require/typed syntax/modresolve
  (resolve-module-path (-> Module-Path Path)))

(module+ test
  (require typed/rackunit))

(: module-path*->stx-predicate (-> (Listof Module-Path) Stx-Pred))
(define (module-path*->stx-predicate mp*)
  (define p* (map module-path->stx-predicate mp*))
  (lambda ([stx : (Syntaxof Any)])
    (for/or ([p (in-list p*)]) : Boolean
      (and p (p stx)))))

(: module-path->stx-predicate (-> Module-Path Stx-Pred))
(define (module-path->stx-predicate mp)
  (define id* (module-path->id-set mp))
  (lambda ([stx : (Syntaxof Any)])
    (and (identifier? stx)
         (free-id-set-member? id* stx)
         ;(printf "YES ~a\n" stx)
         #t)))

(: module-path->id-set (-> Module-Path Free-Id-Set))
(define (module-path->id-set mp)
  (define r (resolve-module-path mp))
  (parameterize ([current-namespace (make-base-namespace)])
    (dynamic-require r (void))
    (define-values (var* stx*) (module->exports r))
    (free-id-set-union
      (provided->id-set var*)
      (provided->id-set stx*))))

(define-type RawProvided (Pairof Phase (Listof (List Symbol History))))
(define-type Phase       (U #f Integer))
(define-type History     (Listof Any)) ;; Lazy

;; Uses `current-namespace` to get identifiers from symbols
(: provided->id-set (-> (Listof RawProvided) Free-Id-Set))
(define (provided->id-set provided**)
  (for/fold : Free-Id-Set
            ([acc : Free-Id-Set (immutable-free-id-set)])
            ([phase+p* (in-list provided**)])
    ;; ignore Phase and History
    (for/fold ([acc acc])
              ([sym+hist (in-list (cdr phase+p*))])
      (free-id-set-add acc (namespace-syntax-introduce #`#,(car sym+hist))))))

;; TODO doc (only the flat ids)
(: syntax->shallow-id-set (-> (Syntaxof Any) Free-Id-Set))
(define (syntax->shallow-id-set stx)
  (define e (syntax-e stx))
  (cond
   [(symbol? e)
    (immutable-free-id-set (list stx))]
   [(list? e)
    (immutable-free-id-set (filter identifier? e))]
   [else
    (immutable-free-id-set)]))

;; -----------------------------------------------------------------------------

(: is-type-ann? Stx-Pred)
(define is-type-ann?
  (module-path->stx-predicate 'typed-racket/base-env/base-types))

(: is-contract? Stx-Pred)
(define is-contract?
  (module-path->stx-predicate 'racket/contract))

;; =============================================================================

(module+ test
  ;; -- module-path->stx-predicate
  ;; -- module-path->symbol*
  ;; -- provided->symbol*
  ;; -- syntax->shallow-id-set
)
