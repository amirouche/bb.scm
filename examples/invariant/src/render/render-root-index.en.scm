;; render-root-index: -> html string for out/index.html (language selector).
(define render-root-index
  (lambda ()
    (str-concat
     (list-of
      "<!doctype html>\n<html lang=\"en\">\n"
      "<head>\n"
      "<meta charset=\"utf-8\">\n"
      "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
      "<title>The Invariant</title>\n"
      "<link rel=\"stylesheet\" href=\"" (site-base) "/style.css\">\n"
      "</head>\n"
      "<body>\n"
      "<header class=\"site\">\n"
      "<h1>The Invariant</h1>\n"
      "<p class=\"tagline\">Stories from the long silence</p>\n"
      "</header>\n"
      "<main>\n"
      "<section>\n"
      "<ol class=\"toc\">\n"
      "<li><a href=\"" (site-base) "/en/index.html\">English</a></li>\n"
      "<li><a href=\"" (site-base) "/fr/index.html\">Fran&#231;ais</a></li>\n"
      "<li><a href=\"" (site-base) "/es/index.html\">Espa&#241;ol</a></li>\n"
      "</ol>\n"
      "</section>\n"
      "</main>\n"
      "<footer class=\"site\">Built in the Hold. Carried into the dark.</footer>\n"
      "</body>\n</html>\n"))))
