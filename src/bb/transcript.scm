(library (bb transcript)

  (export run-transcript-file
          ~check-transcript-basics
          ~check-transcript-recursion
          ~check-transcript-advanced
          ~check-transcript-catamorphic-arith
          ~check-transcript-closures
          ~check-transcript-patterns
          ~check-transcript-00-beyond-babel
          ~check-transcript-01-triple-evolution)

  (import (chezscheme)
          (bb values)
          (bb reader)
          (bb evaluator)
          (bb cli))

  ;; Parse a markdown transcript file and run each code block.
  ;;
  ;; Format: markdown with fenced ```scheme or ```bash blocks.
  ;; After each block:
  ;;   Expected exit code: 0
  ;;   Expected output: <text>
  ;;
  ;; Returns a list of (title pass? actual-exit actual-output) results.

  (define run-transcript-file
    (lambda (path)
      (let ((content (call-with-port (open-input-file path) get-string-all)))
        (run-transcript-string content))))

  (define run-transcript-string
    (lambda (content)
      (let ((blocks (extract-blocks content)))
        ;; Process blocks strictly left-to-right (map order is unspecified in R6RS)
        (let loop ((remaining blocks) (results '()))
          (if (null? remaining)
              (reverse results)
              (loop (cdr remaining)
                    (cons (run-block (car remaining)) results)))))))

  ;; Extract test blocks from markdown.
  ;; Each block is (title source expected-exit expected-output language)
  ;; where language is "scheme" or "bash".
  (define extract-blocks
    (lambda (content)
      (let ((lines (string-split content #\newline)))
        (let loop ((remaining lines)
                   (current-title "untitled")
                   (in-code? #f)
                   (code-lang "scheme")
                   (code-lines '())
                   (blocks '()))
          (if (null? remaining)
              (reverse blocks)
              (let ((line (car remaining))
                    (rest (cdr remaining)))
                (cond
                 ;; Heading line
                 ((and (not in-code?)
                       (> (string-length line) 2)
                       (char=? (string-ref line 0) #\#))
                  (loop rest
                        (string-trim-heading line)
                        #f "scheme" '() blocks))

                 ;; Start of scheme code block
                 ((and (not in-code?)
                       (string-starts-with? line "```scheme"))
                  (loop rest current-title #t "scheme" '() blocks))

                 ;; Start of bash code block
                 ((and (not in-code?)
                       (string-starts-with? line "```bash"))
                  (loop rest current-title #t "bash" '() blocks))

                 ;; End of code block
                 ((and in-code?
                       (string-starts-with? line "```"))
                  (let* ((source (string-join (reverse code-lines) "\n"))
                         (expected (parse-expected rest))
                         (exit-code (car expected))
                         (output (cadr expected)))
                    (loop (cddr-safe rest 2)
                          current-title #f "scheme" '()
                          (cons (list current-title source exit-code output code-lang)
                                blocks))))

                 ;; Inside code block
                 (in-code?
                  (loop rest current-title #t code-lang
                        (cons line code-lines) blocks))

                 ;; Outside code block
                 (else
                  (loop rest current-title #f code-lang '() blocks)))))))))

  ;; Parse "Expected exit code: N" and "Expected output: text" after a block
  (define parse-expected
    (lambda (lines)
      (let loop ((remaining lines)
                 (exit-code 0)
                 (output ""))
        (if (or (null? remaining)
                (and (> (string-length (car remaining)) 0)
                     (char=? (string-ref (car remaining) 0) #\#))
                (string-starts-with? (car remaining) "```"))
            (list exit-code output)
            (let ((line (car remaining)))
              (cond
               ((string-starts-with? line "Expected exit code:")
                (loop (cdr remaining)
                      (string->number (string-trim
                                       (substring line 19 (string-length line))))
                      output))
               ((string-starts-with? line "Expected output:")
                (loop (cdr remaining)
                      exit-code
                      (string-trim
                       (substring line 16 (string-length line)))))
               (else
                (loop (cdr remaining) exit-code output))))))))

  ;; Run a single test block. Returns (title pass? actual-exit actual-output)
  (define run-block
    (lambda (block)
      (let ((title (car block))
            (source (cadr block))
            (expected-exit (caddr block))
            (expected-output (cadddr block))
            (lang (if (> (length block) 4) (list-ref block 4) "scheme")))
        (let-values (((actual-exit actual-output)
                      (if (string=? lang "bash")
                          (eval-bash-with-bb-dispatch source)
                          (eval-capturing-output source))))
          (let ((pass? (and (= actual-exit expected-exit)
                            (equal? (string-trim actual-output)
                                    (string-trim expected-output)))))
            (list title pass? actual-exit actual-output))))))

  ;; Evaluate Möbius source, capturing display output and exit code.
  ;; Returns (values exit-code output-string)
  (define eval-capturing-output
    (lambda (source)
      (let ((output-port (open-output-string)))
        (guard (exn
                (#t (values 1 (get-output-string output-port))))
          (let* ((expressions (mobius-read-all-string source))
                 (env (make-initial-environment)))
            ;; Redirect display output
            (parameterize ((current-output-port output-port))
              (let-values (((final-env value)
                            (mobius-eval-top-level expressions env)))
                (values 0 (get-output-string output-port)))))))))

  ;; Run a bash code block, capturing exit code and stdout.
  ;; Uses a temporary directory for isolation.
  (define eval-bash-capturing-output
    (lambda (source)
      (let* ((tmp-dir (format #f "/tmp/bb-transcript-bash-~a-~a"
                              (time-second (current-time)) (random 1000000)))
             (script-path (string-append tmp-dir "/script.sh"))
             (output-path (string-append tmp-dir "/output.txt")))
        (system (string-append "mkdir -p " tmp-dir))
        (call-with-output-file script-path
          (lambda (port)
            (display "#!/bin/bash\n" port)
            (display "set -e\n" port)
            (display source port)
            (display "\n" port)))
        (let* ((cmd (string-append "cd " tmp-dir " && bash " script-path
                                    " > " output-path " 2>&1"))
               (exit-code (system cmd))
               (raw-output (if (file-exists? output-path)
                               (call-with-port (open-input-file output-path)
                                 get-string-all)
                               ""))
               (output (if (eof-object? raw-output) "" raw-output)))
          (system (string-append "rm -rf " tmp-dir))
          (values exit-code output)))))

  ;; --- In-process bb dispatch for bash blocks ---
  ;;
  ;; Instead of shelling out to the bb binary, dispatch bb commands
  ;; through (bb cli) main so that coverage is reported.

  ;; Find first occurrence of substr in string. Returns index or #f.
  (define string-contains
    (lambda (string substr)
      (let ((text-length (string-length string))
            (substring-length (string-length substr)))
        (and (<= substring-length text-length)
             (let loop ((i 0))
               (cond
                ((> (+ i substring-length) text-length) #f)
                ((string=? (substring string i (+ i substring-length)) substr) i)
                (else (loop (+ i 1)))))))))

  ;; Find index of character in string. Returns index or #f.
  (define string-index
    (lambda (string character)
      (let ((length (string-length string)))
        (let loop ((i 0))
          (cond
           ((= i length) #f)
           ((char=? (string-ref string i) character) i)
           (else (loop (+ i 1))))))))

  ;; Substring before first occurrence of substr.
  (define substring-before
    (lambda (string substr)
      (let ((position (string-contains string substr)))
        (if position
            (substring string 0 position)
            string))))

  ;; Substring after first occurrence of substr.
  (define substring-after
    (lambda (string substr)
      (let ((position (string-contains string substr)))
        (if position
            (substring string (+ position (string-length substr)) (string-length string))
            ""))))

  ;; Check if line ends with string (after trimming).
  (define string-ends-with?
    (lambda (string suffix)
      (let ((text-length (string-length string))
            (suffix-length (string-length suffix)))
        (and (>= text-length suffix-length)
             (string=? (substring string (- text-length suffix-length) text-length) suffix)))))

  ;; Strip shell redirections (> /dev/null, 2>&1) from end of command.
  (define strip-redirections
    (lambda (cmd)
      (let loop ((s (string-trim cmd)))
        (cond
         ((string-ends-with? s "2>&1")
          (loop (string-trim (substring s 0 (- (string-length s) 4)))))
         ((string-ends-with? s "> /dev/null")
          (loop (string-trim (substring s 0 (- (string-length s) 11)))))
         (else s)))))

  ;; Check if command redirects to /dev/null.
  (define has-dev-null-redirect?
    (lambda (cmd)
      (if (string-contains cmd "/dev/null") #t #f)))

  ;; Extract content from echo command: echo 'content' or echo "content".
  (define extract-echo-content
    (lambda (echo-cmd)
      (let* ((trimmed (string-trim echo-cmd))
             (after-echo (if (string-starts-with? trimmed "echo ")
                             (string-trim (substring trimmed 5 (string-length trimmed)))
                             trimmed)))
        (cond
         ;; Single-quoted
         ((and (> (string-length after-echo) 1)
               (char=? (string-ref after-echo 0) #\'))
          (substring after-echo 1 (- (string-length after-echo) 1)))
         ;; Double-quoted
         ((and (> (string-length after-echo) 1)
               (char=? (string-ref after-echo 0) #\"))
          (substring after-echo 1 (- (string-length after-echo) 1)))
         (else after-echo)))))

  ;; Extract heredoc delimiter from "cat <<'DELIM'" or "cat <<DELIM".
  (define extract-heredoc-delimiter
    (lambda (line)
      (let* ((position (string-contains line "<<"))
             (after (string-trim (substring line (+ position 2) (string-length line))))
             (delim-str (substring-before after " "))
             (delim-str (if (string=? delim-str "") after delim-str)))
        ;; Strip surrounding quotes
        (if (and (> (string-length delim-str) 1)
                 (char=? (string-ref delim-str 0) #\'))
            (substring delim-str 1 (- (string-length delim-str) 1))
            delim-str))))

  ;; Collect heredoc lines until delimiter. Returns (content . remaining-lines).
  (define collect-heredoc
    (lambda (lines delimiter)
      (let loop ((remaining lines) (collected '()))
        (if (null? remaining)
            (cons (string-join (reverse collected) "\n") '())
            (if (string=? (string-trim (car remaining)) delimiter)
                (cons (string-join (reverse collected) "\n") (cdr remaining))
                (loop (cdr remaining) (cons (car remaining) collected)))))))

  ;; Split string on spaces, filtering empty strings.
  (define string-split-spaces
    (lambda (string)
      (filter (lambda (s) (not (string=? s "")))
              (string-split (string-trim string) #\space))))

  ;; Parse env var assignments like "EDITOR=true" from a prefix string.
  ;; Returns list of (var . val) pairs.
  (define parse-env-prefix
    (lambda (prefix)
      (let loop ((parts (string-split-spaces prefix)) (result '()))
        (if (null? parts)
            (reverse result)
            (let* ((part (car parts))
                   (equals-position (string-index part #\=)))
              (if equals-position
                  (loop (cdr parts)
                        (cons (cons (substring part 0 equals-position)
                                    (substring part (+ equals-position 1) (string-length part)))
                              result))
                  (loop (cdr parts) result)))))))

  ;; Run a bb command in-process via (bb cli) main.
  ;; Returns (exit-code . output-string).
  ;; Intercepts (exit) to prevent aborting the test runner.
  (define run-bb-command
    (lambda (args stdin-content)
      (let ((output-port (open-output-string)))
        (let ((exit-code
               (call/cc
                (lambda (escape)
                  (guard (exn
                          (#t (escape 1)))
                    (parameterize ((exit-handler (lambda (code) (escape code)))
                                   (current-output-port output-port)
                                   (current-error-port (open-output-string)))
                      (if stdin-content
                          (parameterize ((current-input-port
                                          (open-input-string stdin-content)))
                            (apply main args))
                          (apply main args))
                      0))))))
          (cons exit-code (get-output-string output-port))))))

  ;; Run a bash code block with in-process bb dispatch.
  ;; Processes lines sequentially: bb commands go through main,
  ;; other commands run via shell. Tracks current-directory for cd.
  (define eval-bash-with-bb-dispatch
    (lambda (source)
      (let ((lines (string-split source #\newline))
            (output-port (open-output-string))
            (saved-dir (current-directory)))
        (guard (exn
                (#t
                 (current-directory saved-dir)
                 (values 1 (get-output-string output-port))))
          (let loop ((remaining lines) (last-exit 0))
            (if (null? remaining)
                (begin
                  (current-directory saved-dir)
                  (values last-exit (get-output-string output-port)))
                (let* ((line (car remaining))
                       (trimmed (string-trim line))
                       (rest (cdr remaining)))
                  (cond
                   ;; Empty line — skip
                   ((string=? trimmed "")
                    (loop rest last-exit))

                   ;; cd <path>
                   ((string-starts-with? trimmed "cd ")
                    (let ((path (string-trim
                                 (substring trimmed 3 (string-length trimmed)))))
                      (current-directory path)
                      (loop rest 0)))

                   ;; cat <<'DELIM' | bb <args> ...
                   ((and (string-starts-with? trimmed "cat <<")
                         (string-contains trimmed " | bb "))
                    (let* ((delim (extract-heredoc-delimiter trimmed))
                           (bb-part (substring-after trimmed " | bb "))
                           (bb-cmd (strip-redirections bb-part))
                           (suppress? (has-dev-null-redirect? bb-part))
                           (heredoc+rest (collect-heredoc rest delim))
                           (heredoc-content (car heredoc+rest))
                           (remaining-after (cdr heredoc+rest))
                           (bb-args (string-split-spaces bb-cmd))
                           (result (run-bb-command bb-args heredoc-content)))
                      (unless suppress?
                        (display (cdr result) output-port))
                      (if (and (not (zero? (car result))) (not suppress?))
                          (begin
                            (current-directory saved-dir)
                            (values (car result)
                                    (get-output-string output-port)))
                          (loop remaining-after (car result)))))

                   ;; echo '...' | bb <args> ...
                   ((and (string-starts-with? trimmed "echo ")
                         (string-contains trimmed " | bb "))
                    (let* ((echo-part (substring-before trimmed " | bb "))
                           (stdin-content (extract-echo-content echo-part))
                           (bb-part (substring-after trimmed " | bb "))
                           (bb-cmd (strip-redirections bb-part))
                           (suppress? (has-dev-null-redirect? bb-part))
                           (bb-args (string-split-spaces bb-cmd))
                           (result (run-bb-command
                                    bb-args
                                    (string-append stdin-content "\n"))))
                      (unless suppress?
                        (display (cdr result) output-port))
                      (if (and (not (zero? (car result))) (not suppress?))
                          (begin
                            (current-directory saved-dir)
                            (values (car result)
                                    (get-output-string output-port)))
                          (loop rest (car result)))))

                   ;; bb <args> ... | <shell-suffix>
                   ;; e.g. bb status 2>&1 | grep -c triple
                   ((and (string-starts-with? trimmed "bb ")
                         (string-contains trimmed " | "))
                    (let* ((pipe-pos (string-contains trimmed " | "))
                           (bb-part (substring trimmed 3 pipe-pos))
                           (bb-cmd (strip-redirections bb-part))
                           (bb-args (string-split-spaces bb-cmd))
                           (suffix (string-trim
                                    (substring trimmed (+ pipe-pos 3)
                                               (string-length trimmed))))
                           (result (run-bb-command bb-args #f))
                           (bb-output (cdr result))
                           (tmp-file (format #f "/tmp/bb-pipe-~a"
                                             (random 1000000))))
                      (call-with-output-file tmp-file
                        (lambda (p) (display bb-output p)))
                      (let* ((out-file (string-append tmp-file ".out"))
                             (shell-exit
                              (system (string-append
                                       suffix " < " tmp-file
                                       " > " out-file " 2>&1")))
                             (shell-output
                              (if (file-exists? out-file)
                                  (call-with-port (open-input-file out-file)
                                    get-string-all)
                                  ""))
                             (shell-output
                              (if (eof-object? shell-output) "" shell-output)))
                        (system (string-append "rm -f " tmp-file " " out-file))
                        (display shell-output output-port)
                        (loop rest shell-exit))))

                   ;; ENVVAR=val bb <args> ...
                   ;; e.g. EDITOR=true bb edit double > /dev/null 2>&1
                   ((and (not (string-starts-with? trimmed "bb "))
                         (string-contains trimmed " bb ")
                         (let* ((bb-pos (string-contains trimmed " bb "))
                                (prefix (substring trimmed 0 bb-pos))
                                (parts (string-split-spaces prefix)))
                           (and (not (null? parts))
                                (let loop ((ps parts))
                                  (or (null? ps)
                                      (and (string-contains (car ps) "=")
                                           (loop (cdr ps))))))))
                    (let* ((bb-pos (string-contains trimmed " bb "))
                           (prefix (substring trimmed 0 bb-pos))
                           (bb-part (substring trimmed (+ bb-pos 4)
                                               (string-length trimmed)))
                           (bb-cmd (strip-redirections bb-part))
                           (suppress? (has-dev-null-redirect? bb-part))
                           (bb-args (string-split-spaces bb-cmd))
                           (env-pairs (parse-env-prefix prefix))
                           (old-vals (map (lambda (p)
                                           (cons (car p) (getenv (car p))))
                                         env-pairs)))
                      ;; Set env vars
                      (for-each (lambda (p) (putenv (car p) (cdr p)))
                                env-pairs)
                      (let ((result (run-bb-command bb-args #f)))
                        ;; Restore env vars
                        (for-each (lambda (p)
                                    (if (cdr p)
                                        (putenv (car p) (cdr p))
                                        (putenv (car p) "")))
                                  old-vals)
                        (unless suppress?
                          (display (cdr result) output-port))
                        (loop rest (car result)))))

                   ;; Plain bb <args> [> /dev/null 2>&1]
                   ((string-starts-with? trimmed "bb ")
                    (let* ((after-bb (substring trimmed 3
                                                (string-length trimmed)))
                           (bb-cmd (strip-redirections after-bb))
                           (suppress? (has-dev-null-redirect? after-bb))
                           (bb-args (string-split-spaces bb-cmd))
                           (result (run-bb-command bb-args #f)))
                      (unless suppress?
                        (display (cdr result) output-port))
                      (if (and (not (zero? (car result))) (not suppress?))
                          (begin
                            (current-directory saved-dir)
                            (values (car result)
                                    (get-output-string output-port)))
                          (loop rest (car result)))))

                   ;; Any other line — run via shell
                   (else
                    (let* ((tmp-dir (format #f "/tmp/bb-bash-line-~a"
                                            (random 1000000)))
                           (out-file (string-append tmp-dir "/out.txt")))
                      (system (string-append "mkdir -p " tmp-dir))
                      (let ((shell-exit
                             (system (string-append
                                      "cd " (current-directory)
                                      " && " trimmed
                                      " > " out-file " 2>&1"))))
                        (let* ((shell-output
                                (if (file-exists? out-file)
                                    (call-with-port (open-input-file out-file)
                                      get-string-all)
                                    ""))
                               (shell-output
                                (if (eof-object? shell-output)
                                    "" shell-output)))
                          (system (string-append "rm -rf " tmp-dir))
                          (display shell-output output-port)
                          (if (not (zero? shell-exit))
                              (begin
                                (current-directory saved-dir)
                                (values shell-exit
                                        (get-output-string output-port)))
                              (loop rest shell-exit))))))))))))))

  ;; --- String utilities ---

  (define string-split
    (lambda (string character)
      (let ((length (string-length string)))
        (let loop ((start 0) (i 0) (result '()))
          (cond
           ((= i length)
            (reverse (cons (substring string start length) result)))
           ((char=? (string-ref string i) character)
            (loop (+ i 1) (+ i 1)
                  (cons (substring string start i) result)))
           (else
            (loop start (+ i 1) result)))))))

  (define string-join
    (lambda (strings separator)
      (if (null? strings)
          ""
          (let loop ((remaining (cdr strings))
                     (result (car strings)))
            (if (null? remaining)
                result
                (loop (cdr remaining)
                      (string-append result separator (car remaining))))))))

  (define string-starts-with?
    (lambda (string prefix)
      (and (>= (string-length string) (string-length prefix))
           (string=? (substring string 0 (string-length prefix)) prefix))))

  (define string-trim
    (lambda (string)
      (let ((length (string-length string)))
        (let ((start (let loop ((i 0))
                       (if (and (< i length)
                                (char-whitespace? (string-ref string i)))
                           (loop (+ i 1))
                           i)))
              (end (let loop ((i length))
                     (if (and (> i 0)
                              (char-whitespace? (string-ref string (- i 1))))
                         (loop (- i 1))
                         i))))
          (if (>= start end)
              ""
              (substring string start end))))))

  (define string-trim-heading
    (lambda (line)
      (string-trim
       (let loop ((i 0))
         (if (and (< i (string-length line))
                  (char=? (string-ref line i) #\#))
             (loop (+ i 1))
             (substring line i (string-length line)))))))

  (define cddr-safe
    (lambda (lst n)
      (let loop ((remaining lst) (count n))
        (if (or (zero? count) (null? remaining))
            remaining
            (loop (cdr remaining) (- count 1))))))

  ;; --- Test entry points ---

  ;; Resolve transcript path relative to the first source directory.
  ;; Searches both tests/ and transcripts/ subdirectories.
  (define transcript-path
    (lambda (relative)
      (let loop ((dirs (source-directories)))
        (if (null? dirs)
            relative
            (let* ((dir (car dirs))
                   (dir (if (and (> (string-length dir) 0)
                                 (char=? (string-ref dir (- (string-length dir) 1)) #\/))
                            dir
                            (string-append dir "/")))
                   (candidate-tests (string-append dir "tests/" relative))
                   (candidate-transcripts (string-append dir "transcripts/" relative)))
              (cond
               ((file-exists? candidate-tests) candidate-tests)
               ((file-exists? candidate-transcripts) candidate-transcripts)
               (else (loop (cdr dirs)))))))))

  (define run-and-check
    (lambda (filename)
      (display "  transcript: ") (display filename) (newline)
      (let ((results (run-transcript-file (transcript-path filename))))
        (let loop ((remaining results) (all-pass? #t))
          (if (null? remaining)
              (assert all-pass?)
              (let* ((result (car remaining))
                     (title (car result))
                     (pass? (cadr result))
                     (actual-exit (caddr result))
                     (actual-output (cadddr result)))
                (display "  ")
                (display title)
                (display (if pass? ": PASS" ": FAIL"))
                (unless pass?
                  (display " exit=") (display actual-exit)
                  (display " output=[") (display actual-output) (display "]"))
                (newline)
                (loop (cdr remaining) (and all-pass? pass?))))))))

  (define ~check-transcript-basics
    (lambda () (run-and-check "basics.md")))

  (define ~check-transcript-recursion
    (lambda () (run-and-check "recursion.md")))

  (define ~check-transcript-advanced
    (lambda () (run-and-check "advanced.md")))

  (define ~check-transcript-catamorphic-arith
    (lambda () (run-and-check "catamorphic-arith.md")))

  (define ~check-transcript-closures
    (lambda () (run-and-check "closures.md")))

  (define ~check-transcript-patterns
    (lambda () (run-and-check "patterns.md")))

  (define ~check-transcript-00-beyond-babel
    (lambda () (run-and-check "00-beyond-babel.md")))

  (define ~check-transcript-01-triple-evolution
    (lambda () (run-and-check "01-triple-evolution.md")))

  )
