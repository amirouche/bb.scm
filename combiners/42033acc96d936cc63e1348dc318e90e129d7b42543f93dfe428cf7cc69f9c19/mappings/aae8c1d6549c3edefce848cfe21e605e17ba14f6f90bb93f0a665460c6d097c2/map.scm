((doc . "Log-biased balance criterion (Adams/Nievergelt).\nUses bit-length comparison on sizes, matching the original:\n(lbst<? a b) = (< (bit-length a) (bit-length b))\n(too-big? a b) = (lbst<? a (arithmetic-shift-right b 1))")
 (function . "42033acc96d936cc63e1348dc318e90e129d7b42543f93dfe428cf7cc69f9c19")
 (language . "en")
 (mapping . ((0 . "lbst-too-big?") (1 . "a") (2 . "b"))))