# cat sum.kab.scm
(define agejdu (lambda (amezwaru wis-sin) (+ amezwaru wis-sin)))

# cat sum.fr.scm
(define additionner (lambda (premier deuxième) (+ premier deuxième)))

# cat sum.en.scm
(define add (lambda (first second) (+ first second)))

# bb add sum.kab.scm kab
  staged: agejdu -> ec962a9d0a5ff6a4a1ebaca66e7ce52ea2577427a577ea2013a96e8f4b114019
Done. Use 'bb commit' to finalize.

# bb add sum.fr.scm fr
  staged: additionner -> ec962a9d0a5ff6a4a1ebaca66e7ce52ea2577427a577ea2013a96e8f4b114019
Done. Use 'bb commit' to finalize.

# bb add sum.en.scm en
  staged: add -> ec962a9d0a5ff6a4a1ebaca66e7ce52ea2577427a577ea2013a96e8f4b114019
Done. Use 'bb commit' to finalize.

# bb search ec96
  additionner@ec962a@fr@3c2073a00156
  add@ec962a@en@a1bd96090fee
  agejdu@ec962a@kab@bcbf933ef5f3
3 result(s).

# bb show ec96@kab
(define agejdu
  (lambda (amezwaru wis-sin) (+ amezwaru wis-sin)))

# bb show ec96@fr
(define additionner
  (lambda (premier deuxième) (+ premier deuxième)))

# bb show ec96@en
(define add (lambda (first second) (+ first second)))

# bb diff ec96 ec96
Identical (same hash).

# bb search ec96
  additionner@ec962a@en@c53738df81a7
  add@ec962a@en@a1bd96090fee
  agejdu@ec962a@kab@bcbf933ef5f3
3 result(s).

# bb diff 7f3a 7f3a
Identical (same hash).

# bb eval '(+ 3 4)
7
