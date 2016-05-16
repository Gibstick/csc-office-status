#! /usr/bin/env sh
#|
raco make "${0}" &&
exec racket -u "${0}" ${1+"${@}"}
|#
#lang racket/base

(require scribble/html/html) ; generating HTML
(require scribble/html/xml)  ; outputting XML
(require racket/date)        ; date output
(require racket/system)      ; system
(require racket/file)        ; file utils

;; parameter for lock file
(define lock-file (make-parameter ".office-lock"))
;; parameter for sleep interval
(define sleep-interval (make-parameter 29))
;; parameter for output file
(define output-file (make-parameter "office-status.html"))
;; parameter for html refresh interval
(define refresh-interval (make-parameter 30))
;; parameter for css file
(define css-path (make-parameter "style.css"))
;; parmater for history file path
(define history-file (make-parameter "./office-status-history.csv"))

;; default exit handler
(define default-exit-handler (exit-handler))

;; (handle-break exn) prints out a message and exits with status 0.
;;   The argument exn is ignored.
(define (handle-break exn)
  (displayln "Quitting.")
  (exit 0))


;; (remove-lock-file) removes the lock file if it exists.
;; Effects: lock file is removed
(define (remove-lock)
  (when (file-exists? (lock-file))
    (delete-file (lock-file))))

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
           (p 'class: "footer" (format "Last checked: ~a (local server time)"
                                       (date->string timestamp #t)))
           (a 'class: "footer" 'href: (history-file) "History")
           )
          )
    ))

;; (output-page page) writes the HTML string page
;;   to the current output port.
(define (output-page page)
  (lambda (tmp-port tmp-path-ignored)
    (output-xml (doctype 'html) tmp-port)
    (output-xml page tmp-port)))

;; (output-log-line status timestamp) uses the script's return
;;   status and timestamp to append a line to the log file in csv format.
(define (output-log-line status timestamp)
  (parameterize ([date-display-format 'iso-8601])
    (printf "~a,~a\n"
            (date->string timestamp #t)
            (case status
              [(0) "open"]
              [(1) "closed"]
              [else (format "error ~a" status)]))))


(module+ main
  ;; check for existence of lock file
  (when (file-exists? (lock-file))
    (displayln "Lock file already exists! Exiting." (current-error-port))
    (exit 0))
  
  ;; create lock file
  (define lock (open-output-file (lock-file)))
  
  
  ;; register exit handler to remove lock file
  (exit-handler
   (lambda (x)
     (remove-lock)
     (default-exit-handler x)))
  
  
  ;; run with handler to cleanly exit on break
  (with-handlers
      ([exn:break? handle-break] ; exit handler will delete it
       [exn? (lambda (x)
               (remove-lock)     ; exit handler will not delete it
               (raise x))])      ; since uncaught exceptions don't trigger it
    (let loop ()
      
      ;; call the worker script
      (define exit-code (system/exit-code "./openoffice.sh"))
      
      (define timestamp (current-date))
      
      ;; generate and write html
      (call-with-atomic-output-file
       (output-file)
       (output-page (generate-page exit-code timestamp)))
      
      ;; append to log
      (with-output-to-file (history-file)
        #:exists 'append
        (lambda ()
          (output-log-line exit-code timestamp)))
      
      (sleep 29)
      (loop))))

