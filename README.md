syntax-sloc [![Build Status](https://travis-ci.org/AlexKnauth/syntax-sloc.png?branch=master)](https://travis-ci.org/AlexKnauth/syntax-sloc)
===
A racket package that counts the number of source lines of code in a racket syntax object.

documentation: http://docs.racket-lang.org/syntax-sloc/index.html

```racket
> (require syntax-sloc)

; counting source lines of code in a syntax object:
> (syntax-sloc #'(define (distance x1 y1 x2 y2)
                   ; the distance between the two points is the length
                   ; of the hypotenuse, which is sqrt[(Δx)^2 + (Δy)^2]
                   (sqrt (+ (* (- x2 x1) (- x2 x1))
                            (* (- y2 y1) (- y2 y1))))))
3

; or counting them in a #lang file:
> (current-directory (path-only (collection-file-path "lang-file-sloc.rkt" "syntax-sloc")))
> (lang-file-sloc "lang-file-sloc.rkt")
29
```

On the command line, `raco sloc [<FILE-OR-DIRECTORY>] ...` prints line counts
for its arguments.

```
$ raco sloc lang-file-sloc.rkt
  SLOC  Source
    29  lang-file-sloc.rkt
```
