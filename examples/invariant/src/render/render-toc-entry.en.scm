;; render-toc-entry: lang post (with index n) -> "<li>... <a href=...>title</a></li>"
;; We don't compute n; manifests carry post order, and n is rendered via post-num
;; passed in by the caller — but for the thin slice we just emit the title.
(define render-toc-entry
  (lambda (lang post)
    (str-concat
     (list-of
      "<li><a href=\"" (site-base) "/" lang "/" (post-slug post) ".html\">"
      (escape-html (post-title post))
      "</a></li>\n"))))
