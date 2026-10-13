;; md-render: render a markdown source string to HTML.
;; Subset: #/##/### headings, - bullet lists, blank-line-separated
;; paragraphs, **bold**, *italic*, `code`, [text](url).
;; HTML special characters in the source are always escaped first.
(define md-render
  (lambda (s)
    (md-blocks (md-split-lines (md-escape s)) "" #nil "")))
