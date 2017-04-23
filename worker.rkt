#lang racket
(require "web.rkt"
         db)

;; insert an office status into the db
(define (insert-office-status! db status timestamp)
  (query-exec db "insert into office_statuses values ($1, $2)"
              status timestamp))

;; grab the latest office status and put it in the db
;; should probably run this in a new thread
(define (office-status-main! db)
  (define ts (current-seconds))
  (define-values (subproc _1 _2 _3)
    (subprocess #f #f #f "sh openoffice.sh"))
  (sync/timeout 2 subproc)
  (define status (subprocess-status subproc))
  (insert-office-status! db (if (equal? status 'running) 2 status) ts)
  status)

(module+ main

  (define db (sqlite3-connect #:database (db-path) #:mode 'create))
  (init-db! db)
  
  ;; call worker script in loop
  (define worker-thread
    (thread
     (lambda ()
       (let loop ()
         (define status (office-status-main! db))
         (sleep (sleep-interval))
         (loop)))))

  (thread-wait worker-thread))