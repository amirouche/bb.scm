# Correction: Name Resolution in bb.scm

## My Original Misunderstanding

In my initial analysis, I stated:

> **Bug 1: No name→hash resolution at registration time**
> The `normalize-combiner` function uses a `registry-lookup` parameter to resolve free names to hashes, but this lookup is **not enforced** at `bb add` time.

This was **incorrect**. I missed how the `name-lookup` function is constructed and used.

---

## The Actual Mechanism

### How `bb add` Resolves Names to Hashes

1. **`command-add`** builds a `name-index` from the store:
   ```scheme
   (let* ((root (store-find-root (current-directory)))
          (name-index (store-build-name-index root))
          ...)
   ```

2. **Creates `name-lookup`** via `make-name-lookup`:
   ```scheme
   (define make-name-lookup
     (lambda (name-index root)
       (lambda (sym)
         (let ((name-str (symbol->string sym)))
           (let ((entry (assoc name-str name-index)))
             (if entry
                 (cdr entry)  ;; Return hash from index
                 (guard (exn (#t #f))
                   (let-values (((h l m) (resolve-ref name-index root name-str)))
                     h)))))))  ;; Try resolve-ref as fallback
   ```

3. **Passes to `edit-store-all!`** which calls `normalize-combiner`:
   ```scheme
   (let-values (((normalized-tree mapping)
                 (normalize-combiner value-expression
                                     defined-name
                                     name-lookup)))  ;; <-- name-lookup resolves names
   ```

4. **`normalize-body` uses the lookup** for free symbols:
   ```scheme
   ((symbol? expression)
    (let ((var-binding (assq expression variable-environment)))
      (if var-binding
          ...  ;; Bound variable
          (let ((prim-index (hashtable-ref primitive-name->index expression #f)))
            (if prim-index
                (list 'mobius-primitive-ref prim-index)
                (let ((hash (registry-lookup expression)))  ;; <-- RESOLVES HERE
                  (if hash
                      (list 'mobius-constant-ref hash)
                      (error 'normalize "unbound variable" expression))))))))
   ```

---

## What This Means

### ✅ **Names ARE Resolved at Registration Time**

When you run `bb add file.scm`:
1. The parser reads the file into expressions
2. For each `define`, `normalize-combiner` is called with a `registry-lookup` that:
   - Checks the `name-index` (names → hashes from existing combiners)
   - Falls back to `resolve-ref` for `name@hash@lang@mappingHash` format
3. Free symbols are converted to `(mobius-constant-ref "full-hash")`
4. The tree is stored with **hash references, not names**

### ✅ **The Evaluator is NOT Used for Registration**

The evaluator (`mobius-eval`) is only called in:
- `bb repl` - Interactive REPL
- `bb eval` - Single expression evaluation  
- `bb run` - Running a registered combiner
- During `bb add` - **Only to verify correctness** (via `mobius-eval-top-level`), but the **stored tree uses hashes**

### ✅ **The `name@hash@lang@mappingHash` Format**

This is the **disambiguated reference format** used when:
- Multiple combiners have the same name (collision)
- You want to reference a specific version
- You want to reference a specific language mapping

The `resolve-ref` function handles:
- `name` → looks up in name-index
- `name@hash` → prefix match on hash
- `name@lang` → name with language constraint
- `name@hash@lang` → name + hash prefix + language
- `name@hash@lang@mappingHash` → full disambiguation
- `hash` → direct hash lookup
- `hash@lang` → hash + language
- `hash@mappingHash` → hash + mapping

---

## What I Got Right

Despite missing the name resolution mechanism, I correctly identified:

1. **The evaluator uses name-based lookup** - This is true for `bb repl` and `bb eval`
2. **The stored trees use de Bruijn indices** - This is correct
3. **The content-addressing works** - This is correct (via hash resolution)

## What I Got Wrong

1. **Claimed names aren't resolved at registration** - ❌ **WRONG** - They ARE resolved
2. **Claimed this breaks content-addressing** - ❌ **WRONG** - Content-addressing works correctly
3. **Claimed evaluator is used for dependency resolution** - ⚠️ **PARTIALLY WRONG** - Evaluator is used for verification, but stored trees use hashes

---

## Corrected Bug Analysis

### ❌ **NOT A BUG: Name Resolution at Registration**

**My claim**: "No name→hash resolution at registration time"

**Reality**: Names ARE resolved to hashes at registration time via `name-lookup` → `name-index` → `resolve-ref`

**Status**: ✅ **Working correctly**

---

### ⚠️ **STILL A CONCERN: DAG Enforcement**

While names are resolved to hashes, there's still no validation that:
1. All referenced hashes exist in the store
2. There are no circular dependencies
3. The dependency graph is a DAG

This is still a gap, but it's about **validation**, not **resolution**.

---

### ⚠️ **STILL A CONCERN: Forward References**

The current implementation allows:
```scheme
;; File a.scm
(define a (lambda (x) (b x)))  ;; References b which doesn't exist yet

;; File b.scm  
(define b (lambda (x) (+ x 1)))

;; If you add a.scm first, it will fail with "unbound variable: b"
;; If you add b.scm first, then a.scm, it works
```

The system **does enforce** that dependencies must exist at registration time (via the `name-lookup` function), but it doesn't prevent you from adding combiners in the wrong order.

---

## Updated Understanding

### The Registration Pipeline (Corrected)

```
Source Code
  ↓
Parse (reader.scm) → AST
  ↓
Build name-index from store (name → hash)
  ↓
Create name-lookup function
  ↓
normalize-combiner with name-lookup
  ↓
  - Bound variables → (mobius-variable N)
  - Primitives → (mobius-primitive-ref N)
  - Free names → (mobius-constant-ref "hash")  ← RESOLVED HERE
  ↓
SHA-256 hash of normalized tree
  ↓
Store tree.scm (contains hashes, not names)
  ↓
Store map.scm (language-specific names)
```

### The Evaluation Pipeline

```
Stored tree.scm (contains hashes)
  ↓
Load tree
  ↓
denormalize-tree with hash→name lookup
  ↓
Surface syntax with names restored
  ↓
mobius-eval (name-based evaluator)
```

---

## Why This Matters

The system **does** achieve content-addressing correctly:

1. Same logic in different languages → same normalized tree → same hash
2. References to other combiners → resolved to hashes at registration
3. The stored tree is **independent of names**

The `name@hash@lang@mappingHash` syntax is for **human reference**, not for the internal representation.

---

## Remaining Valid Concerns

From my original analysis, these are **still valid**:

1. ✅ **DAG Enforcement** - No validation of dependency graph
2. ✅ **Guard Implementation** - Missing entry/exit clauses
3. ✅ **Anonymous Combiner Restriction** - Not enforced
4. ✅ **Bare Identifier in Patterns** - Not rejected
5. ✅ **Surface Readers** - Only round surface implemented

These are **NOT valid** (my mistake):

1. ❌ **Name Resolution at Registration** - Actually works correctly
2. ❌ **Content-Addressing Broken** - Actually works correctly

---

## Conclusion

**You were correct to call this out.** The name resolution mechanism is more sophisticated than I initially understood. The system properly resolves names to hashes at registration time using the `name-index` and `resolve-ref` functions.

The evaluator **is** name-based, but it's only used for:
- Interactive evaluation (`bb repl`, `bb eval`)
- Verification during `bb add`
- Running combiners (`bb run`)

The **stored representation** uses hashes, which is what enables content-addressing.

**Thank you for the correction!** This is exactly the kind of detailed review that improves analysis quality.
