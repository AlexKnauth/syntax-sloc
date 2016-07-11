#lang typed/racket/base

(provide read-lang-file lang-file? lang-file-lang)

(require typed/racket/unsafe)

(unsafe-require/typed syntax-sloc/read-lang-file
                      [read-lang-file (-> Path-String (Syntaxof Any))]
                      [lang-file? (-> Path-String Boolean)]
                      [lang-file-lang (-> Path-String String)])

