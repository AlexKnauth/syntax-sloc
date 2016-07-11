#lang typed/racket/base (module+ test

;; End-to-end unit tests for [syntax-sloc with predicates]
;;
;; Parses whole `.rkt` files for their line counts
;;  and compares the automated result to hand-written annotations in the files.

(require typed/rackunit
         racket/runtime-path
         syntax/parse/define
         syntax-sloc/lang-file-sloc
         syntax-sloc/syntax-predicates
         (only-in racket/string string-contains?)
         (only-in syntax-sloc/syntax-sloc Stx-Pred)
         (for-syntax racket/base))

;; IMPORTANT: if you expect a predicate in this list
;;   to count a certain line from a new test file,
;;   annotate that line with
;;     #| TAG |#
;;   where `TAG` is the symbol next to your predicate in the list `predicates`.
;;
;;  For example, every line of Typed Racket type annotation, like:
;;    (: foo (-> Integer Integer))
;;  should be annotated as:
;;    #| T |# (: foo (-> Integer Integer))
;;  to tell the unit tester "if the `is-type-ann?` predicate doesn't recognize
;;  this line, we have a problem!"
(: predicates : (Listof (List Symbol Stx-Pred)))

(define predicates `(
  ;TODO;(T ,is-type-ann?)
  (R ,is-contract?)
))

;; -----------------------------------------------------------------------------

;; For each predicate, compare the hand-annotated count of relevant lines
;;  to the number of lines accepted by the predicate.
(: check-sloc/predicates : Path-String -> Void)
(define (check-sloc/predicates path)
  (for ([tag+p (in-list predicates)]) : Void
    (define-values (tag p) (apply values tag+p))
    (define handwritten-sloc (count-tagged-lines (car tag+p) path))
    (define automatic-sloc (lang-file-sloc path #:include-stx? p))
    (check-equal? automatic-sloc handwritten-sloc
                  (format "~a lines of code in '~a'" tag path))))

;; Count the number of hand-annotated lines in a file.
(: count-tagged-lines : Symbol Path-String -> Natural)
(define (count-tagged-lines tag-sym path)
  (define tag-str (symbol->string tag-sym))
  (define tags-rx
    (pregexp (string-append "^(\\s)?#\\|(.+)\\|#\\s")))
  (with-input-from-file path
    (lambda ()
      (for/sum : Natural
                ([ln (in-lines)])
        (define m (regexp-match tags-rx ln))
        (if (and m (string-contains? (or (caddr m) (error 'rx)) tag-str))
          1
          0)))))

;; -----------------------------------------------------------------------------

(define-simple-macro (define-sloc-test-file path* ...)
  #:with (id* ...) (for/list ([_p (in-list (syntax-e #'(path* ...)))]) (gensym 'path))
  (begin (begin (define-runtime-path id* path*) (check-sloc/predicates id*)) ...))

(define-sloc-test-file
  "data/contract/simple.rkt"
  "data/contract/redefine.rkt"
  "data/contract/rename-in.rkt"
  "data/contract/submodule.rkt"
  "data/contract/url.rkt")

(define-sloc-test-file
  "data/typed-racket/small-type-ann.rkt"
  "data/typed-racket/type-ann.rkt")
)
