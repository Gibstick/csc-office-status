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
(require racket/file)

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
(define history-file (make-parameter "./office-status-history.json"))

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


(define (generate-page status last-checked)
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
                                     last-checked))
         (a 'class: "footer" 'href: (history-file) "History")
         )
        )
  )

(define (output-page page)
  (lambda (tmp-port tmp-path-ignored)
    (output-xml page tmp-port)))


(module+ main
  ;; check for existence of lock file
  (when (file-exists? (lock-file))
    (displayln "Lock file already exists! Exiting." (current-error-port))
    (exit 0))
  
  ;; create lock file
  (begin
    (open-output-file (lock-file))
    (void))
  
  ;; set date format
  (date-display-format 'rfc2822)
  
  ;; register exit handler to remove lock file
  (exit-handler
   (lambda (x)
     (remove-lock)
     (default-exit-handler x)))
  
  
  ;; run with handler to cleanly exit on break
  (with-handlers
      ([exn:break? handle-break]
       [exn? (lambda (x)
               (remove-lock)
               (raise x))])
    (let loop ()
      
      ;; call the worker script
      
      (call-with-atomic-output-file
       (output-file)
       (output-page (generate-page (system/exit-code "./openoffice.sh")
                                   (date->string (current-date) #t))))
      
      (sleep 29)
      (loop))))

