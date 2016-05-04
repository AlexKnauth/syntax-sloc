#lang scribble/manual

@(require scribble-code-examples
          (for-label racket/base
                     racket/contract/base
                     racket/path
                     syntax-sloc
                     ))

@title{Counting Source Lines of Code}

source code: @url{https://github.com/AlexKnauth/syntax-sloc}

@defmodule[syntax-sloc]

@section{Of a Syntax Object}

@defmodule[syntax-sloc/syntax-sloc]

@defproc[(syntax-sloc [stx syntax?]) natural-number/c]{
Counts the number of source lines of code in the syntax object
@racket[stx], not counting whitespace or comments.

It does this by going through every syntax object within it, including
every sub-expression, looking at the @racket[syntax-line] of each one,
and counting how many different lines are there.

@code-examples[#:lang "racket/base" #:context #'here]{
(require syntax-sloc)
(syntax-sloc #'(define (distance x1 y1 x2 y2)
                 ; the distance between the two points is the length
                 ; of the hypotenuse, which is sqrt[(Δx)^2 + (Δy)^2]
                 (sqrt (+ (* (- x2 x1) (- x2 x1))
                          (* (- y2 y1) (- y2 y1))))))
}}

@section{Of a @hash-lang[] file}

@defmodule[syntax-sloc/lang-file-sloc]

@defproc[(lang-file-sloc [path-string path-string?]) natural-number/c]{
Counts the number of source lines of code in the file that
@racket[path-string] points to. This file must start with either
a valid @hash-lang[] line or a racket @racket[module] form. 

@code-examples[#:lang "racket" #:context #'here]{
(require syntax-sloc)
(current-directory (path-only (collection-file-path "lang-file-sloc.rkt" "syntax-sloc")))
(lang-file-sloc "lang-file-sloc.rkt")
(lang-file-sloc "scribblings/syntax-sloc.scrbl")
}}
