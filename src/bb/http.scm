#!chezscheme
(library (bb http)

  (export mobius-url->base-url http-get http-put)

  (import (chezscheme))

  ;; Convert mobius://host/path → http[s]://host/path.
  ;; localhost/127.0.0.1 use plain HTTP; all others use HTTPS.
  (define mobius-url->base-url
    (lambda (url)
      (let* ((rest (substring url 9 (string-length url)))
             (slash (let loop ((i 0))
                      (if (>= i (string-length rest))
                          (string-length rest)
                          (if (char=? (string-ref rest i) #\/)
                              i (loop (+ i 1))))))
             (authority (substring rest 0 slash))
             (colon (let loop ((i 0))
                      (if (>= i (string-length authority)) #f
                          (if (char=? (string-ref authority i) #\:)
                              i (loop (+ i 1))))))
             (host (if colon (substring authority 0 colon) authority))
             (scheme (if (or (string=? host "localhost")
                             (string=? host "127.0.0.1"))
                         "http" "https")))
        (string-append scheme "://" rest))))

  (define %tmpfile
    (lambda ()
      (string-append "/tmp/bb-http-" (number->string (random 1000000000)))))

  ;; Write body bytevector to a temp file; return its path.
  (define %write-temp
    (lambda (bv)
      (let ((path (%tmpfile)))
        (call-with-port
          (open-file-output-port path (file-options) (buffer-mode block))
          (lambda (p) (put-bytevector p bv)))
        path)))

  ;; Run shell command, capture stdout into a temp file, return bytevector.
  (define %capture
    (lambda (cmd)
      (let ((out (%tmpfile)))
        (system (string-append cmd " >" out " 2>/dev/null"))
        (let ((bv (call-with-port
                    (open-file-input-port out)
                    get-bytevector-all)))
          (delete-file out)
          bv))))

  ;; Extract (status-code body-bv) from curl output.
  ;; curl is invoked with -w '\n%{http_code}' so status is the last line.
  (define %parse-status+body
    (lambda (bv)
      (let* ((n (bytevector-length bv))
             (last-nl (let loop ((i (- n 1)))
                        (cond ((< i 0) 0)
                              ((= (bytevector-u8-ref bv i) 10) i)
                              (else (loop (- i 1))))))
             (status (string->number (utf8->string (subbytevector bv (+ last-nl 1) n))))
             (body (subbytevector bv 0 last-nl)))
        (values (or status 0) body))))

  (define subbytevector
    (lambda (bv start end)
      (let ((out (make-bytevector (max 0 (- end start)))))
        (when (> end start)
          (bytevector-copy! bv start out 0 (- end start)))
        out)))

  (define %auth-flag
    (lambda (api-key)
      (if api-key
          (string-append " -H 'Authorization: Bearer " api-key "'")
          "")))

  ;; GET base-url/path → (values status body-bv)
  (define http-get
    (lambda (base-url path api-key)
      (let ((cmd (string-append "curl -s -w '\\n%{http_code}'"
                                (%auth-flag api-key)
                                " '" base-url path "'")))
        (%parse-status+body (%capture cmd)))))

  ;; PUT body-bv to base-url/path → (values status body-bv)
  (define http-put
    (lambda (base-url path body-bv api-key)
      (let* ((tmp (%write-temp body-bv))
             (cmd (string-append "curl -s -X PUT --data-binary @" tmp
                                 " -w '\\n%{http_code}'"
                                 (%auth-flag api-key)
                                 " '" base-url path "'"))
             (out (%capture cmd)))
        (delete-file tmp)
        (%parse-status+body out))))

)
