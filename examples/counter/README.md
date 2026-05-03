# counter — clicker web app

A server-rendered click counter served by `bb serve`. Each button press
increments a score stored in server memory; the score survives page
refreshes for the lifetime of the process.

## What it demonstrates

- **`bb serve <app-ref> <handler-ref>`** — the two-combiner server interface.
  `app-ref` is called once at startup to create shared mutable state;
  `handler-ref` is called on every HTTP request with `(state req)`.

- **`box` / `unbox` / `box!`** as Mobius primitives for in-process mutable
  state shared across requests. The state is a Chez vector (`#(score total
  n0 c0 n1 c1 n2 c2)`) held inside a single box.

- **`xeno`** to call Chez Scheme built-ins (`vector-ref`, `vector-set!`,
  `string-append`, `number->string`, `assoc`, `string->symbol`, `quotient`,
  `char->integer`, `string-ref`) from inside a Mobius combiner, working
  around the constraint that only primitives and committed store combiners
  are available at normalization time.

- A complete round-trip: `bb add` → `bb commit` → `bb remote publish` →
  `bb serve` → browser.

## Structure

| File | Role |
|------|------|
| `src/clicker-state.en.scm` | Application-state factory — `(lambda () (box #(score total n0 c0 n1 c1 n2 c2)))` |
| `src/clicker.en.scm` | Request handler — `(lambda (state req) ...)` with click and upgrade logic |
| `bb-add-all.sh` | One-shot setup: init store, add combiners, publish |
| `bb` | Launcher script pointing at the bb source tree |

## How to run

```sh
cd examples/counter

# 1. Build the store (idempotent — safe to re-run)
./bb-add-all.sh

# 2. Start the server
./bb serve clicker-state clicker --port 8080

# 3. Open in a browser
#    http://localhost:8080/
```

Click the button. Refresh the page — the score persists because it lives
in a `box` held in the server process, not in the browser. Buy upgrades
to increase click value. Each upgrade costs 1.5× more per purchase.

## How the state pattern works

```
bb serve clicker-state clicker
            │                └─ handler: (lambda (state req) ...)
            └─ app factory:  (lambda () (box 0))
```

`transparent` (the io_uring HTTP server) calls the factory **once** at
startup. The returned box is threaded into every request dispatch as
`state`. The handler reads it with `unbox` and mutates it with `box!`.

## Request protocol

The `req` argument is an alist with string keys:

| Key | Type | Example |
|-----|------|---------|
| `"method"` | symbol | `GET`, `POST` |
| `"path"` | string | `"/"` |
| `"params"` | alist | `(("q" . "foo"))` |
| `"body"` | string | `""` |

The handler must return an alist with string keys `"status"` (integer),
`"body"` (string), and optionally `"headers"` (alist of string pairs).
