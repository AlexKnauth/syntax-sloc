#lang racket/base
#| C    |# (require racket/port
#| C    |#          racket/string
#| C    |#          racket/contract/base
#| C    |#          racket/list
#| C    |#          racket/match
#| C    |#          racket/promise
#| C    |#          (prefix-in hc: net/http-client)
#| C    |#          (only-in net/url-connect current-https-protocol)
#| C    |#          net/uri-codec
#| C    |#          net/url-string
#| C    |#          (only-in net/url-exception make-url-exception))

#| C    |# ;; To do:
#| C    |# ;;   Handle HTTP/file errors.
#| C    |# ;;   Not throw away MIME headers.
#| C    |# ;;     Determine file type.

#| C    |# (define-logger net/url)

#| C    |# ;; ----------------------------------------------------------------------

#| C    |# ;; Input ports have two statuses:
#| C    |# ;;   "impure" = they have text waiting
#| C    |# ;;   "pure" = the MIME headers have been read

#| C    |# (define proxiable-url-schemes '("http"))

#| C    |# (define (env->c-p-s-entries envars)
#| C    |#   (if (null? envars)
#| C    |#       null
#| C    |#       (match (getenv (car envars))
#| C    |#         [#f (env->c-p-s-entries (cdr envars))]
#| C    |#         ["" null]
#| C    |#         [(app string->url
#| C    |#               (url (and scheme "http") #f (? string? host) (? integer? port)
#| C    |#                    _ (list) (list) #f))
#| C    |#          (list (list scheme host port))]
#| C    |#         [(app string->url
#| C    |#               (url (and scheme "http") _ (? string? host) (? integer? port)
#| C    |#                    _ _ _ _))
#| C    |#          (log-net/url-error "~s contains somewhat invalid proxy URL format" (car envars))
#| C    |#          (list (list scheme host port))]
#| C    |#         [inv (log-net/url-error "~s contained invalid proxy URL format: ~s"
#| C    |#                                 (car envars) inv)
#| C    |#              null])))

#| C    |# (define current-proxy-servers-promise
#| C    |#   (make-parameter (delay/sync (env->c-p-s-entries '("plt_http_proxy" "http_proxy")))))

#| C    |# (define (proxy-servers-guard v)
#| C    |#   (unless (and (list? v)
#| C    |#                (andmap (lambda (v)
#| C    |#                          (and (list? v)
#| C    |#                               (= 3 (length v))
#| C    |#                               (equal? (car v) "http")
#| C    |#                               (string? (car v))
#| C    |#                               (exact-integer? (caddr v))
#| C    |#                               (<= 1 (caddr v) 65535)))
#| C    |#                        v))
#| C    |#     (raise-type-error
#| C    |#      'current-proxy-servers
#| C    |#      "list of list of scheme, string, and exact integer in [1,65535]"
#| C    |#      v))
#| C    |#   (map (lambda (v)
#| C    |#          (list (string->immutable-string (car v))
#| C    |#                (string->immutable-string (cadr v))
#| C    |#                (caddr v)))
#| C    |#        v))

#| C    |# (define current-proxy-servers
#| C    |#   (make-derived-parameter current-proxy-servers-promise
#| C    |#                           proxy-servers-guard
#| C    |#                           force))

#| C    |# (define (env->n-p-s-entries envars)
#| C    |#   (if (null? envars)
#| C    |#       null
#| C    |#       (match (getenv (car envars))
#| C    |#         [#f (env->n-p-s-entries (cdr envars))]
#| C    |#         ["" null]
#| C    |#         [hostnames (string-split hostnames ",")])))
#| C    |#   
#| C    |# (define current-no-proxy-servers-promise
#| C    |#   (make-parameter (delay/sync (no-proxy-servers-guard (env->n-p-s-entries '("plt_no_proxy" "no_proxy"))))))

#| C    |# (define (no-proxy-servers-guard v)
#| C    |#   (unless (and (list? v)
#| C    |#                (andmap (lambda (v)
#| C    |#                          (or (string? v)
#| C    |#                              (regexp? v)))
#| C    |#                        v))
#| C    |#     (raise-type-error 'current-no-proxy-servers
#| C    |#                       "list of string or regexp"
#| C    |#                       v))
#| C    |#   (map (match-lambda
#| C    |#          [(? regexp? re) re]
#| C    |#          [(regexp "^(\\..*)$" (list _ m))
#| C    |#           (regexp (string-append ".*" (regexp-quote m)))]
#| C    |#          [(? string? s) (regexp (string-append "^"(regexp-quote s)"$"))])
#| C    |#        v))

#| C    |# (define current-no-proxy-servers
#| C    |#   (make-derived-parameter current-no-proxy-servers-promise
#| C    |#                           no-proxy-servers-guard
#| C    |#                           force))

#| C    |# (define (proxy-server-for url-schm (dest-host-name #f))
#| C    |#   (let ((rv (assoc url-schm (current-proxy-servers))))
#| C    |#     (cond [(not dest-host-name) rv]
#| C    |#           [(memf (lambda (np) (regexp-match np dest-host-name)) (current-no-proxy-servers)) #f]
#| C    |#           [else rv])))

#| C    |# (define (url-error fmt . args)
#| C    |#   (raise (make-url-exception
#| C    |#           (apply format fmt
#| C    |#                  (map (lambda (arg) (if (url? arg) (url->string arg) arg))
#| C    |#                       args))
#| C    |#           (current-continuation-marks))))

#| C    |# ;; url->default-port : url -> num
#| C    |# (define (url->default-port url)
#| C    |#   (let ([scheme (url-scheme url)])
#| C    |#     (cond [(not scheme) 80]
#| C    |#           [(string=? scheme "http") 80]
#| C    |#           [(string=? scheme "https") 443]
#| C    |#           [(string=? scheme "git") 9418]
#| C    |#           [else (url-error "URL scheme ~s not supported" scheme)])))

#| C    |# ;; make-ports : url -> hc
#| C    |# (define (make-ports url proxy)
#| C    |#   (let ([port-number (if proxy
#| C    |#                        (caddr proxy)
#| C    |#                        (or (url-port url) (url->default-port url)))]
#| C    |#         [host (if proxy (cadr proxy) (url-host url))])
#| C    |#     (hc:http-conn-open host
#| C    |#                        #:port port-number
#| C    |#                        #:ssl? (if (equal? "https" (url-scheme url))
#| C    |#                                 (current-https-protocol)
#| C    |#                                 #f))))

#| C    |# ;; http://getpost-impure-port : bool x url x union (str, #f) x list (str)
#| C    |# ;;                               -> hc
#| C    |# (define (http://getpost-impure-port get? url post-data strings
#| C    |#                                     make-ports 1.1?)
#| C    |#   (define proxy (proxy-server-for (url-scheme url) (url-host url)))
#| C    |#   (define hc (make-ports url proxy))
#| C    |#   (define access-string
#| C    |#     (ensure-non-empty
#| C    |#      (url->string
#| C    |#       (if proxy
#| C    |#           url
#| C    |#           ;; RFCs 1945 and 2616 say:
#| C    |#           ;;   Note that the absolute path cannot be empty; if none is present in
#| C    |#           ;;   the original URI, it must be given as "/" (the server root).
#| C    |#           (let-values ([(abs? path)
#| C    |#                         (if (null? (url-path url))
#| C    |#                             (values #t (list (make-path/param "" '())))
#| C    |#                             (values (url-path-absolute? url) (url-path url)))])
#| C    |#             (make-url #f #f #f #f abs? path (url-query url) (url-fragment url)))))))

#| C    |#   (hc:http-conn-send! hc access-string
#| C    |#                       #:method (if get? #"GET" #"POST")
#| C    |#                       #:headers strings
#| C    |#                       #:content-decode '()
#| C    |#                       #:data post-data)
#| C    |#   hc)

#| C    |# ;; file://get-pure-port : url -> in-port
#| C    |# (define (file://get-pure-port url)
#| C    |#   (open-input-file (file://->path url)))

#| C    |# (define (schemeless-url url)
#| C    |#   (url-error "Missing protocol (usually \"http:\") at the beginning of URL: ~a" url))

#| C    |# ;; getpost-impure-port : bool x url x list (str) -> in-port
#| C    |# (define (getpost-impure-port get? url post-data strings)
#| C    |#   (let ([scheme (url-scheme url)])
#| C    |#     (cond [(not scheme)
#| C    |#            (schemeless-url url)]
#| C    |#           [(or (string=? scheme "http") (string=? scheme "https"))
#| C    |#            (define hc
#| C    |#              (http://getpost-impure-port get? url post-data strings make-ports #f))
#| C    |#            (http-conn-impure-port hc
#| C    |#                                   #:method (if get? "GET" "POST"))]
#| C    |#           [(string=? scheme "file")
#| C    |#            (url-error "There are no impure file: ports")]
#| C    |#           [else (url-error "Scheme ~a unsupported" scheme)])))

#| C    |# (define (http-conn-impure-port hc
#| C    |#                                #:method [method-bss #"GET"])
#| C    |#   (define-values (in out) (make-pipe 4096))
#| C    |#   (define-values (status headers response-port)
#| C    |#     (hc:http-conn-recv! hc #:method method-bss #:close? #t #:content-decode '()))
#| C    |#   (fprintf out "~a\r\n" status)
#| C    |#   (for ([h (in-list headers)])
#| C    |#     (fprintf out "~a\r\n" h))
#| C    |#   (fprintf out "\r\n")
#| C    |#   (thread
#| C    |#    (λ ()
#| C    |#      (copy-port response-port out)
#| C    |#      (close-output-port out)))
#| C    |#   in)

#| C    |# ;; get-impure-port : url [x list (str)] -> in-port
#| C    |# (define (get-impure-port url [strings '()])
#| C    |#   (getpost-impure-port #t url #f strings))

#| C    |# ;; post-impure-port : url x bytes [x list (str)] -> in-port
#| C    |# (define (post-impure-port url post-data [strings '()])
#| C    |#   (getpost-impure-port #f url post-data strings))

#| C    |# ;; getpost-pure-port : bool x url x list (str) -> in-port
#| C    |# (define (getpost-pure-port get? url post-data strings redirections)
#| C    |#   (let ([scheme (url-scheme url)])
#| C    |#     (cond [(not scheme)
#| C    |#            (schemeless-url url)]
#| C    |#           [(or (string=? scheme "http")
#| C    |#                (string=? scheme "https"))
#| C    |#            (cond
#| C    |#              [(or (not get?)
#| C    |#                   ;; do not follow redirections for POST
#| C    |#                   (zero? redirections))
#| C    |#               (define-values (status headers response-port)
#| C    |#                 (hc:http-conn-recv!
#| C    |#                  (http://getpost-impure-port
#| C    |#                   get? url post-data strings
#| C    |#                   make-ports #f)
#| C    |#                  #:method (if get? #"GET" #"POST")
#| C    |#                  #:content-decode '()
#| C    |#                  #:close? #t))
#| C    |#               response-port]
#| C    |#              [else
#| C    |#               (define-values (port header)
#| C    |#                 (get-pure-port/headers url strings #:redirections redirections))
#| C    |#               port])]
#| C    |#           [(string=? scheme "file")
#| C    |#            (file://get-pure-port url)]
#| C    |#           [else (url-error "Scheme ~a unsupported" scheme)])))

#| C    |# (define (make-http-connection)
#| C    |#   (hc:http-conn))

#| C    |# (define (http-connection-close hc)
#| C    |#   (hc:http-conn-close! hc))

#| C    |# (define (get-pure-port/headers url [strings '()]
#| C    |#                                #:redirections [redirections 0]
#| C    |#                                #:status? [status? #f]
#| C    |#                                #:connection [conn #f])
#| C    |#   (let redirection-loop ([redirections redirections] [url url] [use-conn conn])
#| C    |#     (define hc
#| C    |#       (http://getpost-impure-port #t url #f strings
#| C    |#                                   (if (and use-conn
#| C    |#                                            (hc:http-conn-live? use-conn))
#| C    |#                                     (lambda (url proxy)
#| C    |#                                       (log-net/url-debug "reusing connection")
#| C    |#                                       use-conn)
#| C    |#                                     make-ports)
#| C    |#                                   (and conn #t)))
#| C    |#     (define-values (status headers response-port)
#| C    |#       (hc:http-conn-recv! hc #:method #"GET" #:close? (not conn) #:content-decode '()))

#| C    |#     (define new-url
#| C    |#       (ormap (λ (h)
#| C    |#                (match (regexp-match #rx#"^Location: (.*)$" h)
#| C    |#                  [#f #f]
#| C    |#                  [(list _ m1b)
#| C    |#                   (define m1 (bytes->string/utf-8 m1b))
#| C    |#                   (with-handlers ((exn:fail? (λ (x) #f)))
#| C    |#                     (define next-url (string->url m1))
#| C    |#                     (make-url
#| C    |#                      (or (url-scheme next-url) (url-scheme url))
#| C    |#                      (or (url-user next-url) (url-user url))
#| C    |#                      (or (url-host next-url) (url-host url))
#| C    |#                      (or (url-port next-url) (url-port url))
#| C    |#                      (url-path-absolute? next-url)
#| C    |#                      (url-path next-url)
#| C    |#                      (url-query next-url)
#| C    |#                      (url-fragment next-url)))]))
#| C    |#              headers))
#| C    |#     (define redirection-status-line?
#| C    |#       (regexp-match #rx#"^HTTP/[0-9]+[.][0-9]+ 3[0-9][0-9]" status))
#| C    |#     (cond
#| C    |#       [(and redirection-status-line? new-url (not (zero? redirections)))
#| C    |#        (log-net/url-info "redirection: ~a" (url->string new-url))
#| C    |#        (redirection-loop (- redirections 1) new-url #f)]
#| C    |#       [else
#| C    |#        (values response-port
#| C    |#                (apply string-append
#| C    |#                       (map (λ (x) (format "~a\r\n" x))
#| C    |#                            (if status?
#| C    |#                              (cons status headers)
#| C    |#                              headers))))])))

#| C    |# ;; get-pure-port : url [x list (str)] -> in-port
#| C    |# (define (get-pure-port url [strings '()] #:redirections [redirections 0])
#| C    |#   (getpost-pure-port #t url #f strings redirections))

#| C    |# ;; post-pure-port : url bytes [x list (str)] -> in-port
#| C    |# (define (post-pure-port url post-data [strings '()])
#| C    |#   (getpost-pure-port #f url post-data strings 0))

#| C    |# ;; display-pure-port : in-port -> ()
#| C    |# (define (display-pure-port server->client)
#| C    |#   (copy-port server->client (current-output-port))
#| C    |#   (close-input-port server->client))

#| C    |# ;; call/input-url : url x (url -> in-port) x (in-port -> T)
#| C    |# ;;                  [x list (str)] -> T
#| C    |# (define call/input-url
#| C    |#   (let ([handle-port
#| C    |#          (lambda (server->client handler)
#| C    |#            (dynamic-wind (lambda () 'do-nothing)
#| C    |#                (lambda () (handler server->client))
#| C    |#                (lambda () (close-input-port server->client))))])
#| C    |#     (case-lambda
#| C    |#       [(url getter handler)
#| C    |#        (handle-port (getter url) handler)]
#| C    |#       [(url getter handler params)
#| C    |#        (handle-port (getter url params) handler)])))

#| C    |# ;; purify-port : in-port -> header-string
#| C    |# (define (purify-port port)
#| C    |#   (let ([m (regexp-match-peek-positions
#| C    |#             #rx"^HTTP/.*?(?:\r\n\r\n|\n\n|\r\r)" port)])
#| C    |#     (if m (read-string (cdar m) port) "")))

#| C    |# ;; purify-http-port : in-port -> in-port
#| C    |# (define (purify-http-port in-port)
#| C    |#   (purify-port in-port)
#| C    |#   in-port)

#| C    |# ;; delete-pure-port : url [x list (str)] -> in-port
#| C    |# (define (delete-pure-port url [strings '()])
#| C    |#   (method-pure-port 'delete url #f strings))

#| C    |# ;; delete-impure-port : url [x list (str)] -> in-port
#| C    |# (define (delete-impure-port url [strings '()])
#| C    |#   (method-impure-port 'delete url #f strings))

#| C    |# ;; head-pure-port : url [x list (str)] -> in-port
#| C    |# (define (head-pure-port url [strings '()])
#| C    |#   (method-pure-port 'head url #f strings))

#| C    |# ;; head-impure-port : url [x list (str)] -> in-port
#| C    |# (define (head-impure-port url [strings '()])
#| C    |#   (method-impure-port 'head url #f strings))

#| C    |# ;; put-pure-port : url bytes [x list (str)] -> in-port
#| C    |# (define (put-pure-port url put-data [strings '()])
#| C    |#   (method-pure-port 'put url put-data strings))

#| C    |# ;; put-impure-port : url x bytes [x list (str)] -> in-port
#| C    |# (define (put-impure-port url put-data [strings '()])
#| C    |#   (method-impure-port 'put url put-data strings))

#| C    |# ;; options-pure-port : url [x list (str)] -> in-port
#| C    |# (define (options-pure-port url [strings '()])
#| C    |#   (method-pure-port 'options url #f strings))

#| C    |# ;; options-impure-port : url [x list (str)] -> in-port
#| C    |# (define (options-impure-port url [strings '()])
#| C    |#   (method-impure-port 'options url #f strings))

#| C    |# ;; method-impure-port : symbol x url x list (str) -> in-port
#| C    |# (define (method-impure-port method url data strings)
#| C    |#   (let ([scheme (url-scheme url)])
#| C    |#     (cond [(not scheme)
#| C    |#            (schemeless-url url)]
#| C    |#           [(or (string=? scheme "http") (string=? scheme "https"))
#| C    |#            (http://method-impure-port method url data strings)]
#| C    |#           [(string=? scheme "file")
#| C    |#            (url-error "There are no impure file: ports")]
#| C    |#           [else (url-error "Scheme ~a unsupported" scheme)])))

#| C    |# ;; method-pure-port : symbol x url x list (str) -> in-port
#| C    |# (define (method-pure-port method url data strings)
#| C    |#   (let ([scheme (url-scheme url)])
#| C    |#     (cond [(not scheme)
#| C    |#            (schemeless-url url)]
#| C    |#           [(or (string=? scheme "http") (string=? scheme "https"))
#| C    |#            (let ([port (http://method-impure-port
#| C    |#                         method url data strings)])
#| C    |#              (purify-http-port port))]
#| C    |#           [(string=? scheme "file")
#| C    |#            (file://get-pure-port url)]
#| C    |#           [else (url-error "Scheme ~a unsupported" scheme)])))

#| C    |# ;; http://metod-impure-port : symbol x url x union (str, #f) x list (str) -> in-port
#| C    |# (define (http://method-impure-port method url data strings)
#| C    |#   (let* ([method (case method
#| C    |#                    [(get) "GET"] [(post) "POST"] [(head) "HEAD"]
#| C    |#                    [(put) "PUT"] [(delete) "DELETE"] [(options) "OPTIONS"] 
#| C    |#                    [else (url-error "unsupported method: ~a" method)])]
#| C    |#          [proxy (proxy-server-for (url-scheme url) (url-host url))]
#| C    |#          [hc (make-ports url proxy)]
#| C    |#          [access-string
#| C    |#           (ensure-non-empty
#| C    |#            (url->string
#| C    |#             (if proxy
#| C    |#                 url
#| C    |#                 (make-url #f #f #f #f
#| C    |#                           (url-path-absolute? url)
#| C    |#                           (url-path url)
#| C    |#                           (url-query url)
#| C    |#                           (url-fragment url)))))])
#| C    |#     (hc:http-conn-send! hc access-string
#| C    |#                         #:method method
#| C    |#                         #:headers strings
#| C    |#                         #:content-decode '()
#| C    |#                         #:data data)
#| C    |#     (http-conn-impure-port hc
#| C    |#                            #:method method)))

#| C    |# (define (ensure-non-empty s)
#| C    |#   (if (string=? "" s)
#| C    |#       "/"
#| C    |#       s))

#| C    |# ;(provide (all-from-out "url-string.rkt"))

#| C  R |# (provide/contract
#| C  R |#  (get-pure-port (->* (url?) ((listof string?) #:redirections exact-nonnegative-integer?) input-port?))
#| C  R |#  (get-impure-port (->* (url?) ((listof string?)) input-port?))
#| C  R |#  (post-pure-port (->* (url? (or/c false/c bytes?)) ((listof string?)) input-port?))
#| C  R |#  (post-impure-port (->* (url? bytes?) ((listof string?)) input-port?))
#| C  R |#  (head-pure-port (->* (url?) ((listof string?)) input-port?))
#| C  R |#  (head-impure-port (->* (url?) ((listof string?)) input-port?))
#| C  R |#  (delete-pure-port (->* (url?) ((listof string?)) input-port?))
#| C  R |#  (delete-impure-port (->* (url?) ((listof string?)) input-port?))
#| C  R |#  (put-pure-port (->* (url? (or/c false/c bytes?)) ((listof string?)) input-port?))
#| C  R |#  (put-impure-port (->* (url? bytes?) ((listof string?)) input-port?))
#| C  R |#  (options-pure-port (->* (url?) ((listof string?)) input-port?))
#| C  R |#  (options-impure-port (->* (url?) ((listof string?)) input-port?))
#| C  R |#  (display-pure-port (input-port? . -> . void?))
#| C  R |#  (purify-port (input-port? . -> . string?))
#| C  R |#  (get-pure-port/headers (->* (url?)
#| C  R |#                              ((listof string?)
#| C    |#                               #:redirections exact-nonnegative-integer?
#| C    |#                               #:status? boolean?
#| C  R |#                               #:connection (or/c #f hc:http-conn?))
#| C    |#                              (values input-port? string?)))
#| C  R |#  (rename hc:http-conn? http-connection? (any/c . -> . boolean?))
#| C  R |#  (make-http-connection (-> hc:http-conn?))
#| C  R |#  (http-connection-close (hc:http-conn? . -> . void?))
#| C  R |#  (call/input-url (case-> (-> url?
#| C  R |#                              (-> url? input-port?)
#| C  R |#                              (-> input-port? any)
#| C  R |#                              any)
#| C  R |#                          (-> url?
#| C  R |#                              (-> url? (listof string?) input-port?)
#| C  R |#                              (-> input-port? any)
#| C  R |#                              (listof string?)
#| C  R |#                              any)))
#| C    |#  (current-proxy-servers
#| C  R |#   (parameter/c (or/c false/c (listof (list/c string? string? number?)))))
#| C    |#  (current-no-proxy-servers
#| C  R |#   (parameter/c (or/c false/c (listof (or/c string? regexp?)))))
#| C  R |#  (proxy-server-for (->* (string?) ((or/c false/c string?))
#| C  R |#                         (or/c false/c (list/c string? string? number?))))
#| C  R |#  (proxiable-url-schemes (listof string?)))

#| C    |# (define (http-sendrecv/url u
#| C    |#                            #:method [method-bss #"GET"]
#| C    |#                            #:headers [headers-bs empty]
#| C    |#                            #:data [data #f]
#| C    |#                            #:content-decode [decodes '(gzip)])
#| C    |#   (unless (member (url-scheme u) '(#f "http" "https"))
#| C    |#     (error 'http-sendrecv/url "URL scheme ~e not supported" (url-scheme u)))
#| C    |#   (define ssl?
#| C    |#     (equal? (url-scheme u) "https"))
#| C    |#   (define port
#| C    |#     (or (url-port u)
#| C    |#         (if ssl?
#| C    |#           443
#| C    |#           80)))
#| C    |#   (unless (url-host u)
#| C    |#     (error 'http-sendrecv/url "Host required: ~e" u))
#| C    |#   (hc:http-sendrecv
#| C    |#    (url-host u)
#| C    |#    (ensure-non-empty
#| C    |#     (url->string
#| C    |#      (make-url #f #f #f #f
#| C    |#                (url-path-absolute? u)
#| C    |#                (url-path u)
#| C    |#                (url-query u)
#| C    |#                (url-fragment u))))
#| C    |#    #:ssl?
#| C    |#    (if (equal? "https" (url-scheme u))
#| C    |#      (current-https-protocol)
#| C    |#      #f)
#| C    |#    #:port port
#| C    |#    #:method method-bss
#| C    |#    #:headers headers-bs
#| C    |#    #:data data
#| C    |#    #:content-decode decodes))

#| C    |# (provide
#| C  R |#  (contract-out
#| C    |#   [http-sendrecv/url
#| C  R |#    (->* (url?)
#| C  R |#         (#:method (or/c bytes? string? symbol?)
#| C  R |#                   #:headers (listof (or/c bytes? string?))
#| C  R |#                   #:data (or/c false/c bytes? string? hc:data-procedure/c)
#| C  R |#                   #:content-decode (listof symbol?))
#| C  R |#         (values bytes? (listof bytes?) input-port?))]))
