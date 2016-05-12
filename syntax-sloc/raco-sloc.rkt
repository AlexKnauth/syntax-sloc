#lang racket/base

;; Command-line interface for computing SLOC

(require syntax-sloc
         (only-in syntax-sloc/read-lang-file lang-file?)
         racket/format)

;; -----------------------------------------------------------------------------

(define SLOC-HEADER "SLOC\tSource")

(define MAX-PATH-WIDTH 40) ;; characters

;; Get SLOC for `src`, output a string with pretty-printed results
;; format-sloc : (Path-String -> Natural) Path-String -> String
(define (format-sloc get-sloc src)
  (string-append (~r (get-sloc src) #:min-width 4)
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

(module+ main
  (require racket/cmdline)
  (command-line
   #:program "syntax-sloc"
   ;; TODO optional arguments
   #:args FILE-OR-DIRECTORY
   (displayln SLOC-HEADER)
   (for ([src (in-list FILE-OR-DIRECTORY)])
     (displayln
       (cond
        [(directory-exists? src)
         (format-sloc directory-sloc src)]
        [(lang-file? src)
         (format-sloc lang-file-sloc src)]
        [else
         (missing-sloc src)])))))

