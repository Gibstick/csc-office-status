#! /usr/bin/env sh
#|
raco make "${0}" &&
exec racket -u "${0}" ${1+"${@}"}
|#
#lang racket/base

(require scribble/html/html scribble/html/xml) ; generating HTML
(require racket/date)        ; date output
(require racket/match)       ; match-define
(require web-server/servlet  ; server stuff
         web-server/servlet-env)
(require db)
(require racket/vector)      ; vector-map
(require racket/cmdline)
(require racket/port)        ; port->string
(require racket/string)
(require net/base64)

(provide db-path
         init-db!
         sleep-interval)

;; parameter for sleep interval
(define sleep-interval (make-parameter 60))
;; number of seconds between page refresh
(define refresh-interval (make-parameter 60))
;; path to stylesheet
(define css-path (make-parameter "static/style.css"))
;; sqlite db
(define db-path (make-parameter "office_status.db"))
;; servlet params
(define servlet-path (make-parameter "/"))
(define servlet-port (make-parameter 58888))
(define servlet-command-line (make-parameter #t))


;; status codes
;; 0 - open
;; 1 - closed
;; 2 - worker script timed out
;; 5 - could not fetch webcam stream

(define css-data-uri ; lol
  (string-append
   "data:text/css;charset=utf-8;base64,"
   (with-output-to-string
       (lambda ()
         (with-input-from-file (css-path)
           (lambda ()
             (base64-encode-stream (current-input-port) (current-output-port) "")))))))
#;(with-input-from-file (css-path)
    (lambda () (base64-encode (port->bytes) "")))

;; (generate-page status timestamp) produces a string of the page's HTML
;;   ready to be written to a file, using the script's return status
;;   and timestamp.
(define (generate-page status timestamp)
  (parameterize ([date-display-format 'rfc2822])
    (html 'lang: "en"
          (head
           (meta 'http-equiv: "refresh" 'content: (refresh-interval))
           #;(element 'link 'rel: "stylesheet" 'href:
                      (css-path))
           (meta 'name: "viewport" 'content: "width=device-width"
                 'initial-scale: "1.0" 'user-scalable: "yes")
           #;(style 'type: "text/css"
                  (minify-css!))
           (link 'href: css-data-uri 'rel: "stylesheet")
           (title
            (case status
              [(0) "Open"]
              [(1) "Closed"]
              [else "Unknown"])
            )
           )
          (body
           (h1 "Is the CSC office open?")
           (p
            (case status
              [(0) "Yes."]
              [(1) "No."]
              [(5) "Unknown. Could not fetch webcam stream."]
              [(#f) "No data yet. Is the worker script running?"]
              [else (format "Unknown. Script exited with status ~a." status)])
            )
           (when timestamp
             (div 'class: "footer"
                  (p (format "Last checked: ~a"
                             (date->string (seconds->date timestamp) #t)))
                  (let ([time-diff (- (current-seconds) timestamp)])
                    (when (> time-diff (* 5 (sleep-interval)))
                      (p (format "Note: No updates since ~a seconds ago"
                                 time-diff))))))
           )
          )
    ))



(define (init-db! db)
  (query-exec db #<<"""
create table if not exists office_statuses
  (status INTEGER NOT NULL, ts INTEGER PRIMARY KEY NOT NULL)
"""
              ))

;; query the latest office status from the db
(define (latest-office-status db)
  (vector-map
   sql-null->false
   (query-maybe-row db "select status, max(ts) from office_statuses")))


(module+ main
  (define db (sqlite3-connect #:database (db-path) #:mode 'create))
  (init-db! db)

  (define (main-route req)
    (eprintf "got request: ~a\n" req)
    (define row
      (latest-office-status db))
    (define status (and row (vector-ref row 0)))
    (define ts (and row (vector-ref row 1)))
    (eprintf "status, ts: ~a, ~a\n" status ts)
    (response/output
     (lambda (out)
       (output-xml (generate-page status ts) out))))

  (command-line
   #:once-each
   [("-p" "--port") port "Set the port for the server to listen on"
                    (servlet-port (string->number port))]
   [("-w" "--web-browser") "Launch a web browser pointing to the main entrypoint"
                           (servlet-command-line #f)])

  ;; serve web page
  (serve/servlet main-route
                 #:listen-ip #f
                 #:servlet-regexp #rx""
                 #:port (servlet-port)
                 #:command-line? (servlet-command-line)))
