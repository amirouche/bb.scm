;; turtle-example: example name -> preset program text. Known names
;; are square, spiral, star; any other name yields the square.
(define turtle-example
  (lambda (name)
    (if (xeno "string=?" name "spiral")
        "color red repeat 36 [ forward 100 right 10 ]"
        (if (xeno "string=?" name "star")
            "color blue repeat 5 [ forward 200 right 144 ]"
            "repeat 4 [ forward 100 right 90 ]"))))
