#lang typed/racket/base

(require racket/match
         racket/list)
(module+ test
  (require typed/rackunit))

(define-type ResModPath
  (U Path Symbol
     (List* 'submod (U Path Symbol) (Listof Symbol))))

(require/typed pkg/lib
               [pkg-directory
                (-> String (U #false Path-String))]
               [pkg-directory->module-paths
                (-> Path-String String (Listof Module-Path))])

(require/typed syntax/modresolve
               [resolve-module-path
                (-> Module-Path (U False Path-String) ResModPath)])

;; ------------------------------------------------------------------------

(provide pkg-module-paths
         pkg-module-file-paths)

(: pkg-module-paths : String -> (Listof Module-Path))
(define (pkg-module-paths name)
  (pkg-directory->module-paths (assert (pkg-directory name)) name))

(: pkg-module-file-paths : String -> (Listof Path))
(define (pkg-module-file-paths name)
  (remove-duplicates
   (map module-path->file-path
        (pkg-module-paths name))))

(module+ test
  (: list-contains-subset? : (Listof Any) (Listof Any) -> Boolean)
  (define (list-contains-subset? as bs)
    (for/and ([b (in-list bs)]) : Boolean
      (and (member b as) #t)))

  (check list-contains-subset?
         (pkg-module-file-paths "lang-file")
         (list
          (resolve-module-path
           '(lib "lang-file/read-lang-file.rkt")
           #false)
          (resolve-module-path
           '(lib "lang-file/scribblings/read-lang-file.scrbl")
           #false))))

;; ------------------------------------------------------------------------

(: module-path->file-path : Module-Path -> Path)
(define (module-path->file-path mp)
  (let loop ([mp : ResModPath (resolve-module-path mp #false)])
    (cond
      [(path? mp) mp]
      [(symbol? mp)
       (error 'module-path->file-path
              "expected path, given: ~v" mp)]
      [else
       (match mp
         [`(submod ,mp . ,_)
          (loop mp)])])))

;; ------------------------------------------------------------------------

