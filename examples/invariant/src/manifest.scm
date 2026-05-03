;; manifest: lang -> list of posts. Dispatches on lang via gamma.
(define manifest
  (gamma
   (("en") (manifest-en))
   (("fr") (manifest-fr))
   (("es") (manifest-es))))
