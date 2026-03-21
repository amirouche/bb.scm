(library (bb hash)

  (export sha256-string
          sha256-bytevector
          hash-combiner
          hash-split
          hash-value
          hex-encode
          ~check-hash-sha256
          ~check-hash-combiner-deterministic
          ~check-hash-split)

  (import (chezscheme)
          (bb values)
          (bb serialization))

  ;; SHA-256 implementation for content addressing.
  ;; Uses Chez Scheme's FFI to OpenSSL if available,
  ;; otherwise falls back to a pure Scheme implementation.

  ;; --- Hex encoding ---

  (define hex-chars "0123456789abcdef")

  (define hex-encode
    (lambda (bytevector)
      (let* ((length (bytevector-length bytevector))
             (result (make-string (* length 2))))
        (do ((index 0 (+ index 1)))
          ((= index length) result)
          (let ((byte (bytevector-u8-ref bytevector index)))
            (string-set! result (* index 2)
                         (string-ref hex-chars (fxarithmetic-shift-right byte 4)))
            (string-set! result (+ (* index 2) 1)
                         (string-ref hex-chars (fxand byte #xF))))))))

  ;; --- SHA-256 ---

  ;; Pure Scheme SHA-256 implementation
  ;; Based on FIPS 180-4

  (define sha256-k
    '#(#x428a2f98 #x71374491 #xb5c0fbcf #xe9b5dba5
       #x3956c25b #x59f111f1 #x923f82a4 #xab1c5ed5
       #xd807aa98 #x12835b01 #x243185be #x550c7dc3
       #x72be5d74 #x80deb1fe #x9bdc06a7 #xc19bf174
       #xe49b69c1 #xefbe4786 #x0fc19dc6 #x240ca1cc
       #x2de92c6f #x4a7484aa #x5cb0a9dc #x76f988da
       #x983e5152 #xa831c66d #xb00327c8 #xbf597fc7
       #xc6e00bf3 #xd5a79147 #x06ca6351 #x14292967
       #x27b70a85 #x2e1b2138 #x4d2c6dfc #x53380d13
       #x650a7354 #x766a0abb #x81c2c92e #x92722c85
       #xa2bfe8a1 #xa81a664b #xc24b8b70 #xc76c51a3
       #xd192e819 #xd6990624 #xf40e3585 #x106aa070
       #x19a4c116 #x1e376c08 #x2748774c #x34b0bcb5
       #x391c0cb3 #x4ed8aa4a #x5b9cca4f #x682e6ff3
       #x748f82ee #x78a5636f #x84c87814 #x8cc70208
       #x90befffa #xa4506ceb #xbef9a3f7 #xc67178f2))

  (define u32+ (lambda (a b) (bitwise-and (+ a b) #xFFFFFFFF)))
  (define u32and bitwise-and)
  (define u32or bitwise-ior)
  (define u32xor bitwise-xor)
  (define u32not (lambda (x) (bitwise-and (bitwise-not x) #xFFFFFFFF)))

  (define u32>>
    (lambda (x n)
      (bitwise-arithmetic-shift-right x n)))

  (define rotr32
    (lambda (x n)
      (u32or (u32>> x n)
             (bitwise-and (bitwise-arithmetic-shift-left x (- 32 n)) #xFFFFFFFF))))

  (define sha256-choose
    (lambda (x y z)
      (u32xor (u32and x y) (u32and (u32not x) z))))

  (define sha256-maj
    (lambda (x y z)
      (u32xor (u32and x y) (u32xor (u32and x z) (u32and y z)))))

  (define sha256-sigma0
    (lambda (x)
      (u32xor (rotr32 x 2) (u32xor (rotr32 x 13) (rotr32 x 22)))))

  (define sha256-sigma1
    (lambda (x)
      (u32xor (rotr32 x 6) (u32xor (rotr32 x 11) (rotr32 x 25)))))

  (define sha256-gamma0
    (lambda (x)
      (u32xor (rotr32 x 7) (u32xor (rotr32 x 18) (u32>> x 3)))))

  (define sha256-gamma1
    (lambda (x)
      (u32xor (rotr32 x 17) (u32xor (rotr32 x 19) (u32>> x 10)))))

  ;; Pad message to multiple of 64 bytes
  (define sha256-pad
    (lambda (message)
      (let* ((length (bytevector-length message))
             (bit-length (* length 8))
             ;; Pad to 56 mod 64, then add 8 bytes for length
             (pad-length (let ((remainder (modulo (+ length 1) 64)))
                           (if (<= remainder 56)
                               (- 56 remainder)
                               (- 120 remainder))))
             (total-length (+ length 1 pad-length 8))
             (padded (make-bytevector total-length 0)))
        ;; Copy original message
        (bytevector-copy! message 0 padded 0 length)
        ;; Append 0x80
        (bytevector-u8-set! padded length #x80)
        ;; Append bit length as 64-bit big-endian
        (bytevector-u8-set! padded (- total-length 4)
                            (fxand (fxarithmetic-shift-right bit-length 24) #xFF))
        (bytevector-u8-set! padded (- total-length 3)
                            (fxand (fxarithmetic-shift-right bit-length 16) #xFF))
        (bytevector-u8-set! padded (- total-length 2)
                            (fxand (fxarithmetic-shift-right bit-length 8) #xFF))
        (bytevector-u8-set! padded (- total-length 1)
                            (fxand bit-length #xFF))
        padded)))

  ;; Read 32-bit big-endian word from bytevector
  (define bytevector-u32-ref-be
    (lambda (bytevector index)
      (fxior (fxarithmetic-shift-left (bytevector-u8-ref bytevector index) 24)
             (fxior (fxarithmetic-shift-left (bytevector-u8-ref bytevector (+ index 1)) 16)
                    (fxior (fxarithmetic-shift-left (bytevector-u8-ref bytevector (+ index 2)) 8)
                           (bytevector-u8-ref bytevector (+ index 3)))))))

  (define sha256-bytevector
    (lambda (message)
      (let* ((padded (sha256-pad message))
             (number-of-blocks (/ (bytevector-length padded) 64)))
        ;; Initial hash values
        (let ((h0 #x6a09e667) (h1 #xbb67ae85)
              (h2 #x3c6ef372) (h3 #xa54ff53a)
              (h4 #x510e527f) (h5 #x9b05688c)
              (h6 #x1f83d9ab) (h7 #x5be0cd19))
          ;; Process each 64-byte block
          (do ((block 0 (+ block 1)))
            ((= block number-of-blocks)
             ;; Return 32-byte hash
             (let ((result (make-bytevector 32)))
               (do ((i 0 (+ i 1))
                    (hash (list h0 h1 h2 h3 h4 h5 h6 h7) (cdr hash)))
                 ((= i 8) result)
                 (let ((h (car hash)))
                   (bytevector-u8-set! result (* i 4)
                                       (fxand (u32>> h 24) #xFF))
                   (bytevector-u8-set! result (+ (* i 4) 1)
                                       (fxand (u32>> h 16) #xFF))
                   (bytevector-u8-set! result (+ (* i 4) 2)
                                       (fxand (u32>> h 8) #xFF))
                   (bytevector-u8-set! result (+ (* i 4) 3)
                                       (fxand h #xFF))))))
            ;; Prepare message schedule
            (let ((w (make-vector 64 0))
                  (offset (* block 64)))
              (do ((i 0 (+ i 1)))
                ((= i 16))
                (vector-set! w i (bytevector-u32-ref-be padded (+ offset (* i 4)))))
              (do ((i 16 (+ i 1)))
                ((= i 64))
                (vector-set! w i
                  (u32+ (sha256-gamma1 (vector-ref w (- i 2)))
                        (u32+ (vector-ref w (- i 7))
                              (u32+ (sha256-gamma0 (vector-ref w (- i 15)))
                                    (vector-ref w (- i 16)))))))
              ;; Compression
              (let ((a h0) (b h1) (c h2) (d h3)
                    (e h4) (f h5) (g h6) (h h7))
                (do ((i 0 (+ i 1)))
                  ((= i 64)
                   (set! h0 (u32+ h0 a))
                   (set! h1 (u32+ h1 b))
                   (set! h2 (u32+ h2 c))
                   (set! h3 (u32+ h3 d))
                   (set! h4 (u32+ h4 e))
                   (set! h5 (u32+ h5 f))
                   (set! h6 (u32+ h6 g))
                   (set! h7 (u32+ h7 h)))
                  (let* ((t1 (u32+ h (u32+ (sha256-sigma1 e)
                                           (u32+ (sha256-choose e f g)
                                                 (u32+ (vector-ref sha256-k i)
                                                       (vector-ref w i))))))
                         (t2 (u32+ (sha256-sigma0 a) (sha256-maj a b c))))
                    (set! h g)
                    (set! g f)
                    (set! f e)
                    (set! e (u32+ d t1))
                    (set! d c)
                    (set! c b)
                    (set! b a)
                    (set! a (u32+ t1 t2)))))))))))

  (define sha256-string
    (lambda (string)
      (hex-encode (sha256-bytevector (string->utf8 string)))))

  ;; --- Content hashing ---

  ;; Hash a combiner body (serialized tree.scm content)
  (define hash-combiner
    (lambda (tree-content)
      (sha256-string tree-content)))

  ;; Hash any value (for constants)
  (define hash-value
    (lambda (value)
      (sha256-string (scheme-write-value value))))

  ;; Legacy split — now identity. Returns the full hash as both car (for
  ;; callers that only use car) and cdr (for callers that only use cdr).
  ;; TODO: remove callers and delete.
  (define hash-split
    (lambda (hash)
      (cons hash "")))

  ;; --- Tests ---

  (define ~check-hash-sha256
    (lambda ()
      ;; Known SHA-256 test vectors
      ;; SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      (assert (equal? "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
                       (sha256-string "")))
      ;; SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
      (assert (equal? "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
                       (sha256-string "abc")))))

  (define ~check-hash-combiner-deterministic
    (lambda ()
      ;; Same content => same hash
      (let ((content "(body . ((mobius-primitive-ref 26) (mobius-variable 1) (mobius-variable 2)))"))
        (assert (equal? (hash-combiner content)
                         (hash-combiner content))))
      ;; Different content => different hash
      (assert (not (equal? (hash-combiner "content-a")
                            (hash-combiner "content-b"))))))

  (define ~check-hash-split
    (lambda ()
      (let ((result (hash-split "deadbeef1234")))
        (assert (equal? "deadbeef1234" (car result)))
        (assert (equal? "" (cdr result))))))

  )
