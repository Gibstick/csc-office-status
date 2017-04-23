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

(provide db-path
         init-db!
         sleep-interval)

;; parameter for sleep interval
(define sleep-interval (make-parameter 60))
;; number of seconds between page refresh
(define refresh-interval (make-parameter 60))
;; path to stylesheet
(define css-path (make-parameter "style.css"))
;; sqlite db
(define db-path (make-parameter "office_status.db"))


;; status codes
;; 0 - open
;; 1 - closed
;; 2 - worker script timed out
;; 5 - could not fetch webcam stream


;; (generate-page status timestamp) produces a string of the page's HTML
;;   ready to be written to a file, using the script's return status
;;   and timestamp.
(define (generate-page status timestamp)
  (parameterize ([date-display-format 'rfc2822])
    (html 'lang: "en"
          (head
           (meta 'http-equiv: "refresh" 'content: (refresh-interval))
           (element 'link 'rel: "stylesheet" 'href: (css-path))
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
              [else (format "Unknown. Script exited with status ~a." status)])
            )
           (div 'class: "footer"
                (p (format "Last checked: ~a"
                           (date->string (seconds->date timestamp) #t)))
                (let ([time-diff (- (current-seconds) timestamp)])
                  (when (> time-diff (* 5 (sleep-interval)))
                    (p (format "Note: No updates since ~a seconds ago"
                               time-diff)))))
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
  (query-maybe-row db "select status, max(ts) from office_statuses"))


(module+ main
  (define db (sqlite3-connect #:database (db-path) #:mode 'create))
  (init-db! db)

  (define (main-route req)
    (eprintf "got request: ~a\n" req)
    (define row
      (latest-office-status db))
    (define status (and row (vector-ref row 0)))
    (define ts (and row (vector-ref row 1)))
    (response/output
     (lambda (out)
       (output-xml (generate-page status ts) out))))

  ;; serve web page
  (serve/servlet main-route
                 #:servlet-path "/"
                 #:extra-files-paths
                 (list (build-path "static"))
                 #:command-line? #t))

