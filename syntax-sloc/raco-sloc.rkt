#lang racket/base

;; Command-line interface for computing SLOC

(require syntax-sloc
         (only-in syntax-sloc/read-lang-file lang-file?)
         (only-in racket/list last)
         (only-in racket/string string-trim)
         (only-in racket/port call-with-input-string peeking-input-port)
         (only-in racket/format ~a ~r))

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

;; lang-line-match : Pregexp -> Path-String -> Boolean
(define (lang-line-match? px src)
  (define lang-line (call-with-input-file src read-#lang))
  (and lang-line (regexp-match-exact? px lang-line)))

;; read-#lang : Input-Port -> (U #f String)
(define (read-#lang port)
  (define end-pos
    (let* ([lang-in (peeking-input-port port)])
      (and (procedure? (with-handlers ([exn:fail? (lambda (e) #f)])
                         (read-language lang-in)))
           (file-position lang-in))))
  (define str (and end-pos (read-string end-pos (peeking-input-port port))))
  (define lang-posn* (and (string? str) (regexp-match-positions* "#lang|#!" str)))
  (and lang-posn*
       (string-trim (substring str (cdr (last lang-posn*))))))

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
   (displayln SLOC-HEADER)
   (define matching-lang? ;; : Path-String -> Boolean
     (let ([px (*lang-file-pregexp*)])
       (if px
         (lambda (src) (lang-line-match? px (if (path? src) (path->string src) src)))
         (lambda (src) #t))))
   (define (directory-sloc/filter src)
     (directory-sloc src #:use-file? matching-lang?))
   (for ([src (in-list FILE-OR-DIRECTORY)])
     (displayln
       (cond
        [(directory-exists? src)
         (format-sloc directory-sloc/filter src)]
        [(and (lang-file? src) (matching-lang? src))
         (format-sloc lang-file-sloc src)]
        [else
         (missing-sloc src)])))))

(module+ test
  (require rackunit)

  (define (read-#lang-from-strings . str*)
    (call-with-input-string (apply string-append str*) read-#lang))

  ;; -- basic #langs
  (check-equal?
    (read-#lang-from-strings
      "#lang racket/base\n"
      "(+ 1 2")
    "racket/base")
  (check-equal?
    (read-#lang-from-strings
      "#lang racket/base\n"
      "(+ 1 2)")
    "racket/base")
  (check-equal?
    (read-#lang-from-strings
      "\n\n#lang racket\n")
    "racket")
  (check-equal?
    (read-#lang-from-strings
      "#lang scribble/manual\n"
      "some text for scribble\n")
    "scribble/manual")
  (check-equal?
    (read-#lang-from-strings
      "   #lang typed/racket")
    "typed/racket")

  ;; -- confusing #langs
  (check-equal?
    (read-#lang-from-strings
      "#!racket")
    "racket")
  (check-equal?
    (read-#lang-from-strings
      ";; extra comment\n"
      "#lang racket/base \n"
      "(+ 1 2)")
    "racket/base")
  (check-equal?
    (read-#lang-from-strings
      "#| another kind of comment \n"
      "|#\n"
      "#lang scribble/html")
    "scribble/html")
  (check-equal?
    (read-#lang-from-strings
      "#lang at-exp racket")
    "at-exp racket")
  (check-equal?
    (read-#lang-from-strings
      "#|#lang scribble/manual|# #!racket")
    "racket")

   ;; -- failures
  (check-false
    (read-#lang-from-strings
      "#lang #| bad comment |# racket"))
  (check-false
    (read-#lang-from-strings
      "#lang     racket\n"
      ";; has too many spaces\n"))
)
