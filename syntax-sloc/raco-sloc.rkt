#lang racket/base

;; Command-line interface for computing SLOC

(require syntax-sloc
         (only-in syntax-sloc/read-lang-file lang-file? lang-file-lang)
         (only-in racket/format ~a ~r))

;; -----------------------------------------------------------------------------

(define SLOC-HEADER "SLOC\tSource")

(define MAX-PATH-WIDTH 40) ;; characters

;; format-sloc : Natural Path-String -> String
(define (format-sloc sloc src)
  (string-append (~r sloc #:min-width 4)
                 "\t"
                 (format-filepath src)))

;; Print a filepath, truncate if too long
;; format-filepath : Path-String -> String
(define (format-filepath src)
  (~a src #:max-width MAX-PATH-WIDTH
          #:limit-marker "..."
          #:limit-prefix? #t))

;; missing-sloc : String -> String
(define (missing-sloc src)
  (string-append " N/A" "\t" src))

;; lang-line-match? : Pregexp Path-String -> Boolean
(define (lang-line-match? px src)
  (define lang-line (lang-file-lang src))
  (and lang-line (regexp-match-exact? px lang-line)))


(module+ main
  (require racket/cmdline)
  (define *lang-file-pregexp* (make-parameter #f))
  (command-line
   #:program "syntax-sloc"
   #:once-each
   [("-l" "--lang")
    lang-pregexp
    "Only count files with a matching #lang line"
    (*lang-file-pregexp* (pregexp lang-pregexp))]
   #:args FILE-OR-DIRECTORY
   (define px (*lang-file-pregexp*))
   (displayln SLOC-HEADER)
   (define matching-lang? ;; : Path-String -> Boolean
     (if px
         (lambda (src) (lang-line-match? px src))
         (lambda (src) #t)))
   (define total-sloc
     (for/sum ([src (in-list FILE-OR-DIRECTORY)])
       (define sloc ;; (U #f Natural)
         (cond
          [(directory-exists? src)
           (directory-sloc src #:use-file? matching-lang?)]
          [(and (lang-file? src) (matching-lang? src))
           (lang-file-sloc src)]
          [else
           #f]))
       (displayln
         (if sloc
           (format-sloc sloc src)
           (missing-sloc src)))
       (or sloc 0)))
   (displayln (format-sloc total-sloc "total"))))

