;; site-meta: lang -> (title tagline footer)
;; Returns the per-language site-level strings used by render-page,
;; render-index, and the language switcher.
(define site-meta
  (gamma
   (("en")
    (cons "The Invariant"
          (cons "Stories from the long silence"
                (cons "Built in the Hold. Carried into the dark."
                      #nil))))
   (("fr")
    (cons "L'Invariant"
          (cons "Récits du grand silence"
                (cons "Construit dans la Cale. Emporté dans le noir."
                      #nil))))
   (("es")
    (cons "El Invariante"
          (cons "Relatos del silencio largo"
                (cons "Construido en la Bodega. Llevado a la oscuridad."
                      #nil))))))
