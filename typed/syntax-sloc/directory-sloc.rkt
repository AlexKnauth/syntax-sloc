#lang typed/racket/base

(require syntax-sloc/directory-sloc)
(provide: [directory-sloc (-> Path-String [#:use-file? (-> Path Boolean)] Natural)])

