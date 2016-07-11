#lang typed/racket/base

;; Command-line interface for computing SLOC

(require syntax-sloc
         (only-in typed/syntax-sloc/read-lang-file lang-file? lang-file-lang)
         (only-in racket/port with-input-from-string)
         (only-in racket/string string-join string-prefix? string-suffix?)
         (only-in racket/format ~a ~r))

;; -----------------------------------------------------------------------------

(define SLOC-HEADER "SLOC~a\tSource")

(define MAX-PATH-WIDTH 40) ;; characters

;; Get SLOC for `src`, output a string with pretty-printed results
(: format-sloc : (Path-String -> Natural) Path-String -> String)
(define (format-sloc get-sloc src)
  (string-append (~r (get-sloc src) #:min-width 4)
                 "\t"
                 (format-filepath src)))

;; Print a filepath, truncate if too long
(: format-filepath : Path-String -> String)
(define (format-filepath src)
  (~a src #:max-width MAX-PATH-WIDTH
          #:limit-marker "..."
          #:limit-prefix? #t))

(: missing-sloc : String -> String)
(define (missing-sloc src)
  (string-append " N/A" "\t" src))

(: lang-line-match? : Regexp Path-String -> Boolean)
(define (lang-line-match? px src)
  (define lang-line (lang-file-lang src))
  (and lang-line (regexp-match-exact? px lang-line)))

;; -----------------------------------------------------------------------------

(: module-option-help : (Listof (U (List Symbol String) (List Symbol String Stx-Pred))))
(define module-option-help
`(
  (contract
   "racket/contract contract values"
   ,is-contract?)
  (type-ann
   "Typed Racket type annotations"
   ,is-type-ann?)
  (<module-path>
   "Lines with identifiers provided by <module-path>")
  (listof-<module-path>
   "Lines with identifiers provided by any module in the list")
))

(: string->stx-pred : String -> Stx-Pred)
(define (string->stx-pred str)
  (define sym (string->symbol str))
  (define builtin-pred
    (for/or : Stx-Pred
            ([sym+desc (in-list module-option-help)]
             #:when (and (eq? sym (car sym+desc))
                         (not (null? (cddr sym+desc)))))
      (caddr sym+desc)))
  (cond
   [builtin-pred
    builtin-pred]
   [(module-path? sym)
    (module-path->stx-predicate sym)]
   [else
    #f]))

(: string->stx-pred/fail : String -> Stx-Pred)
(define (string->stx-pred/fail str)
  (or (string->stx-pred str)
      (raise-user-error 'raco-sloc "Unrecognized module '~a'." str)))

;; Format the current syntax object filter for console output.
;; (Will go in the header for the "~a" in "SLOC~a")
(: module-path-string->header : (U #f String) -> String)
(define (module-path-string->header s)
  (if s (format "(~a)" s) ""))

;; -----------------------------------------------------------------------------

(module+ main
  (require racket/cmdline)
  (define *lang-file-pregexp* : (Parameterof (U #f Regexp)) (make-parameter #f))
  (define *mp-string* : (Parameterof (U #f String)) (make-parameter #f))
  (define *stx-preds* : (Parameterof (U #f (Listof Stx-Pred)))
    (make-parameter #f))
  (command-line
   #:program "syntax-sloc"
   #:once-each
   [("-l" "--lang")
    lang-pregexp
    "Only count files with a matching #lang line"
    (*lang-file-pregexp* (pregexp (assert lang-pregexp string?)))]
   [("-m" "--module")
    mp
    [(string-join
      (cons (format "One of ~a. Only count lines from matching syntax objects, defined as:\n" (map (inst car Symbol Any) module-option-help))
            (for/list : (Listof String) ([sym+desc (in-list module-option-help)])
              (~a "  - " (car sym+desc) " : " (cadr sym+desc))))
      "\n")]
    (let* ([mp-str (assert mp string?)]
           [pred (string->stx-pred/fail mp-str)]
           [old-preds (or (*stx-preds*) '())])
      (*mp-string* mp-str)
      (*stx-preds* (cons pred old-preds)))]
   #:args FILE-OR-DIRECTORY
   (define px (*lang-file-pregexp*))
   (printf SLOC-HEADER (module-path-string->header (*mp-string*)))
   (newline)
   (define matching-lang? : (-> Path-String Boolean)
     (if px
         (lambda ((src : Path-String)) (lang-line-match? px src))
         (lambda ((src : Path-String)) #t)))
   (define include-stx? : Stx-Pred
     (let ([preds (*stx-preds*)])
       (if preds
         (lambda ([x : (Syntaxof Any)])
           (for/and ([p (in-list preds)]) : Boolean
             (and p (p x))))
         #f)))
   (define (directory-sloc/filter (src : Path-String)) : Natural
     (directory-sloc src #:use-file? matching-lang? #:include-stx? include-stx?))
   (define (lang-file-sloc/filter (src : Path-String)) : Natural
     (lang-file-sloc src #:include-stx? include-stx?))
   (for ([any (in-list FILE-OR-DIRECTORY)])
     (define src (assert any string?))
     (displayln
       (cond
        [(directory-exists? src)
         (format-sloc directory-sloc/filter src)]
        [(and (lang-file? src) (matching-lang? src))
         (format-sloc lang-file-sloc/filter src)]
        [else
         (missing-sloc src)])))))

