#lang scribble/manual

@(require scribble-code-examples
          (only-in scribble/bnf nonterm)
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

@section{Of a directory}

@defmodule[syntax-sloc/directory-sloc]

@defproc[(directory-sloc [path-string path-string?]
                         [#:use-file? use-file? (-> path? boolean?) (λ (path) #t)])
         natural-number/c]{
Counts the number of source lines of code in all @hash-lang[] files
recursively contained inside the directory that @racket[path-string] points to,
except for the ones that @racket[use-file?] returns false for.

@code-examples[#:lang "racket" #:context #'here]{
(require syntax-sloc)
(current-directory (path-only (collection-file-path "lang-file-sloc.rkt" "syntax-sloc")))
(directory-sloc (current-directory))
;; ext is a byte string containing the expected extension, without the dot
(define ((has-extension? ext) path)
  (equal? (filename-extension path) ext))
(directory-sloc (current-directory)
                #:use-file? (has-extension? #"rkt"))
(directory-sloc (current-directory)
                #:use-file? (has-extension? #"scrbl"))
}}

@section{Of a package}

@defmodule[syntax-sloc/pkg-sloc]

@defproc[(pkg-sloc [name string?]
                   [#:use-file? use-file? (-> path? boolean?) (λ (path) #t)])
         natural-number/c]{
Counts the number of source lines of code in all @hash-lang[] files
provided by the package with the given @racket[name], except the ones
that @racket[use-file?] returns false for.

@;{

Currently the examples are broken because it can't take the lock for
pkg stuff while the docs are building. Or maybe I need to configure
the sandbox differently, I don't know.

@code-examples[#:lang "racket" #:context #'here]{
(require syntax-sloc)
(pkg-sloc "syntax-sloc")
;; ext is a byte string containing the expected extension, without the dot
(define ((has-extension? ext) path)
  (equal? (filename-extension path) ext))
(pkg-sloc "syntax-sloc"
           #:use-file? (has-extension? #"rkt"))
(pkg-sloc "syntax-sloc"
          #:use-file? (has-extension? #"scrbl"))
}

}}

@section{On the command line: @exec{raco sloc}}

The @exec{raco sloc} command counts source lines of code in files or directories
named on the command line and prints results.
If an argument to @exec{raco sloc} is not a @hash-lang[] file or a directory,
its line count is not computed.

Available flags:
@itemlist[
  @item{
    @DFlag{lang} @nonterm{lang-pregexp} --- Only count lines for files whose
      @hash-lang[] string exactly matches the @nonterm{lang-pregexp} regular
      expression.
      For example @DFlag{lang} @tt{racket} will match @tt{#lang racket} and
      @tt{#!racket} but not @tt{#lang racket/base} or @tt{#lang sweet-exp racket}.
  }
]
