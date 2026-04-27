(define afficher-page
  (lambda (lang inner)
    (str-concat
     (list-of
      "<!doctype html>\n<html lang=\"" lang "\">\n"
      "<head>\n"
      "<meta charset=\"utf-8\">\n"
      "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
      "<title>" (escape-html (site-title lang)) "</title>\n"
      "<link rel=\"stylesheet\" href=\"" (site-base) "/style.css\">\n"
      "</head>\n"
      "<body>\n"
      "<header class=\"site\">\n"
      "<h1><a href=\"" (site-base) "/" lang "/index.html\">" (escape-html (site-title lang)) "</a></h1>\n"
      "<p class=\"tagline\">" (escape-html (site-tagline lang)) "</p>\n"
      (lang-switcher lang)
      "</header>\n"
      "<main>\n"
      inner
      "</main>\n"
      "<footer class=\"site\">"
      (escape-html (site-footer lang))
      "</footer>\n"
      "</body>\n</html>\n"))))
