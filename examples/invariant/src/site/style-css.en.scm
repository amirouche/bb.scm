;; style-css: returns the shared stylesheet string.
;; Wrapped as a thunk because top-level defines must be combiners.
(define style-css
  (lambda ()
    "/* The Invariant — shared stylesheet */
:root {
  --bg: #f4f1ec;
  --ink: #1a1a1a;
  --rule: #c9c0b3;
  --link: #5a3a1a;
  --muted: #6a6259;
  --measure: 36rem;
}
* { box-sizing: border-box; }
body {
  background: var(--bg);
  color: var(--ink);
  font: 17px/1.55 Georgia, 'Iowan Old Style', serif;
  margin: 0;
  padding: 2.5rem 1.25rem 4rem;
}
main, header, footer { max-width: var(--measure); margin: 0 auto; }
header.site {
  border-bottom: 1px solid var(--rule);
  padding-bottom: 1rem;
  margin-bottom: 2rem;
}
header.site h1 {
  font-size: 1.6rem;
  margin: 0 0 .25rem;
  letter-spacing: .02em;
}
header.site .tagline {
  margin: 0;
  color: var(--muted);
  font-style: italic;
  font-size: .95rem;
}
nav.langs { margin-top: .75rem; font-size: .9rem; }
nav.langs a { margin-right: .75rem; }
a { color: var(--link); text-decoration: none; border-bottom: 1px solid var(--rule); }
a:hover { border-bottom-color: var(--link); }
article header h2 {
  font-size: 1.4rem;
  margin: 2rem 0 .25rem;
}
article p { margin: 0 0 1rem; }
.meta { color: var(--muted); font-size: .9rem; margin-top: 0; }
nav.post {
  display: flex;
  justify-content: space-between;
  margin: 2.5rem 0 1rem;
  padding-top: 1rem;
  border-top: 1px solid var(--rule);
  font-size: .95rem;
}
ol.toc { list-style: none; padding: 0; }
ol.toc li { padding: .35rem 0; border-bottom: 1px dashed var(--rule); }
ol.toc .num { color: var(--muted); margin-right: .5rem; }
footer.site {
  margin-top: 4rem;
  padding-top: 1rem;
  border-top: 1px solid var(--rule);
  color: var(--muted);
  font-size: .85rem;
  font-style: italic;
}
"))
