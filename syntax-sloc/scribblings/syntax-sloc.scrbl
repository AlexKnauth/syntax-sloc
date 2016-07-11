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

@defproc[(syntax-sloc [stx syntax?]
                      [#:use-stx? use-stx? (or/c #f (-> syntax? boolean?) #f)])
         natural-number/c]{
Counts the number of source lines of code in the syntax object
@racket[stx], not counting whitespace or comments.
If @racket[use-stx?] is a procedure, the count is only for syntax objects
that @racket[use-stx?] returns @racket[#t] for.

Line counts are computed by going through every syntax object within @racket[stx],
including every sub-expression, looking at the @racket[syntax-line] of each one
(that @racket[use-stx?] does not return @racket[#f] for),
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

@defproc[(lang-file-sloc [path-string path-string?]
                         [#:use-stx? use-stx? (or/c #f (-> syntax? boolean?) #f)])
         natural-number/c]{
Counts the number of source lines of code in the file that
@racket[path-string] points to. This file must start with either
a valid @hash-lang[] line or a racket @racket[module] form.
Use @racket[use-stx?] is not @racket[#f], the count excludes lines from syntax
objects that @racket[use-stx?} returns @racket[#f] for.

@code-examples[#:lang "racket" #:context #'here]{
(require syntax-sloc)
(current-directory (path-only (collection-file-path "lang-file-sloc.rkt" "syntax-sloc")))
(lang-file-sloc "lang-file-sloc.rkt")
(lang-file-sloc "scribblings/syntax-sloc.scrbl")
}}

@section{Of a directory}

@defmodule[syntax-sloc/directory-sloc]

@defproc[(directory-sloc [path-string path-string?]
                         [#:use-file? use-file? (-> path? boolean?) (λ (path) #t)]
                         [#:use-stx? use-stx? (or/c #f (-> syntax? boolean?) #f)])
         natural-number/c]{
Counts the number of source lines of code in all @hash-lang[] files
recursively contained inside the directory that @racket[path-string] points to,
except for files that @racket[use-file?] returns false for and syntax objects
that @racket[use-stx?] returns false for.

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

@section{On the command line: @exec{raco sloc}}

The @exec{raco sloc} command counts source lines of code in files or directories
named on the command line and prints results.
If an argument to @exec{raco sloc} is not a @hash-lang[] file or a directory,
its line count is not computed.

Available flags:
@itemlist[
  @item{
    @DFlag{module} @nonterm{module-path} --- Only count lines containing
      identifiers from the module (or list of modules) @nonterm{module-path}.
      For instance, @exec{raco sloc --module racket/string *.rkt} counts only
       lines using identifiers from @racket[racket/string].

      Certain symbols represent a pre-defined group of module paths e.g.
       @exec{raco sloc --module type-ann *.rkt} will approximate the number of
       type annotations in files.
      Use @exec{raco sloc --help} for more info.
  }
  @item{
    @DFlag{lang} @nonterm{lang-pregexp} --- Only count lines for files whose
      @hash-lang[] string exactly matches the @nonterm{lang-pregexp} regular
      expression.
      For example @DFlag{lang} @tt{racket} will match @tt{#lang racket} and
      @tt{#!racket} but not @tt{#lang racket/base} or @tt{#lang sweet-exp racket}.
  }
]
