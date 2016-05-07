#lang typed/racket/base

(require/typed/provide syntax-sloc/directory-sloc
                       [directory-sloc (-> Path-String [#:use-file? (-> Path Boolean)] Natural)])

