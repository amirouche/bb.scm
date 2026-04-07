((doc . "Log-biased balance criterion (Adams/Nievergelt).\nUses bit-length comparison on sizes, matching the original:\n(lbst<? a b) = (< (bit-length a) (bit-length b))\n(too-big? a b) = (lbst<? a (arithmetic-shift-right b 1))")
 (function . "7f445ff66aa676b478f9061277110f5088c2b98436f4ee76467866267526eac7")
 (language . "en")
 (mapping . ((0 . "lbst-too-big?") (1 . "a") (2 . "b"))))