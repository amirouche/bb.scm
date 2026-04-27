;; lang-switcher: lang -> "<nav class=langs>...</nav>" string with three links.
;; Each link goes to that language's index page.
(define lang-switcher
  (lambda (lang)
    (str-concat
     (list-of
      "<nav class=\"langs\">"
      "<a href=\"" (site-base) "/en/index.html\">English</a>"
      "<a href=\"" (site-base) "/fr/index.html\">français</a>"
      "<a href=\"" (site-base) "/es/index.html\">español</a>"
      "</nav>\n"))))
