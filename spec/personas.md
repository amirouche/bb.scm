# Möbius Personas — Angles of Incidence

*Same kaleidoscope, different colors. Each persona sees Möbius from a different angle. None of them are wrong. None of them see the whole thing.*

---

## Quick Map

**Who arrives and why — the 17 personas:**

| # | Persona | What brings them |
|---|---------|-----------------|
| 1 | The Garage Lab Hacker | Priority without permission |
| 2 | The Polyglot Programmer | Names in their language, as originals |
| 3 | The PL Theorist | Economy, catamorphism, the deliberate exclusions |
| 4 | The Burned-Out Senior Dev | What Möbius removes |
| 5 | The Civilizational Thinker | Infrastructure that outlasts its moment |
| 6 | The Kid in Tizi Ouzou | The tool works when they pick it up |
| 7 | The Academic Researcher | Priority before publication, reproducibility is the hash |
| 8 | The Independent Researcher | The hash *is* the institution |
| 9 | The Community Steward | Collective knowledge, non-individual attribution |
| 10 | The Privateer | Priority proof without disclosure |
| 11 | The Person Who Was Stolen From | Grief, then recognition |
| 12 | The Connector | Findability across difference |
| 13 | The Educator | Lessons with traceable lineage |
| 14 | The Artist | Demoscene, music, Blender — derivation as honor |
| 15 | The Citizen | Illegibility of power, made auditable |
| 16 | The Representative | Trust under complexity, decisions with traceable provenance |
| 17 | The Symbiotic Artificial Intelligence | The commons as external memory, the hash as trust anchor |

**What anyone can do once here — the 7 roles:**

| Role | Workflow | Skill |
|------|----------|-------|
| Author | `bb edit`, `bb check`, `bb commit`, `bb refactor` | Writing content, declaring lineage |
| Forker | `bb edit hash@lang`, `bb check`, `bb commit` (derived-from) | Making derivation explicit |
| Maintainer | `bb check`, `bb diff`, `bb review --status`, `bb refactor` | Keeping the graph honest |
| Linguistic Contributor | `bb add name file target-language` | Language and meaning |
| Reviewer | `bb review` | Trust and accountability |
| Curator | `bb search` | Pattern recognition, legibility |
| Coordinator | `bb add` (checks) | Problem definition |
| Operator | `bb sync`, `bb remote` | Redundancy, survival |

---

## How Roles Relate

The roles are not a hierarchy. They are a loop.

**Coordinator defines → Author builds → Forker derives → Maintainer propagates → Coordinator refines.**

The Coordinator writes checks — "here is what correct means." But they're writing into the dark. They don't know yet what edge cases the real world will surface.

The Author writes to those checks. `bb check` tells them if they're correct. But passing checks doesn't mean the checks were right.

The Forker discovers the edges — the cases where the original didn't quite fit, where a fix or extension was needed. Their `derived-from` makes the gap visible.

The Maintainer discovers, over time, that a check suite was incomplete. A bug that `bb check` didn't catch. A path that broke after propagation. That discovery is the signal the Coordinator needs to refine the spec.

So the loop closes: the Maintainer's work feeds back to the Coordinator. Neither role is complete without the other — not because one outranks the other, but because the system only improves if someone enforces the standard over time and reports what the standard missed.

**To get started, you only need two roles:** Coordinator and Author. One person writes checks that define the problem. One person writes content that passes them. Everything else — Forker, Maintainer, Reviewer, Linguistic Contributor, Curator, Operator — grows from that minimum viable commons.

In a garage lab, those two roles are often the same person. That's fine. The separation becomes meaningful when a second person arrives.

---

## The Personas

---

### 1. The Garage Lab Hacker

**Orientation:** Builds things alone or in tiny crews. Ships from literal garages, bedrooms, cafés. Has been burned by platforms that absorbed their work without credit. Distrusts institutions but believes in infrastructure.

**What lights up:** Content-addressing + OpenTimestamps. The hash is the proof. Priority via timestamps, not via who has the biggest platform. No permission needed to ship, no coordination needed to share. Send a hash, done.

**The pitch in their language:** "Your work is yours. The timestamp proves you made it. The hash proves it works. Nobody can absorb it without the lineage being visible. Ship from your garage and the trace is permanent."

**Entry point:** The dependency DAG and name-centric workflow. How `freedom → hash_v2` works. The practical difference from git. They'll start by putting their own code in the mobius-store and feeling the difference.

**What they'd miss:** The multilingual dimension. They probably code in English and don't feel the friction. The civilizational stakes might read as grandiose until they see someone else's garage lab in Algiers or Dakar using the same infrastructure with names in their own language.

**What scares them:** "Is this vaporware?" They've seen too many ambitious projects die. The running interpreter is the answer. Show, don't tell.

---

### 2. The Polyglot Programmer

**Orientation:** Speaks multiple human languages. Codes in English because they have to, not because they want to. Feels the friction every day — naming things in a language that isn't theirs, reading documentation that assumes their cultural context, contributing to projects where their natural way of thinking is treated as a translation layer.

**What lights up:** Multilingual naming. `"odd?" → 0x7a3f...` / `"impair?" → 0x7a3f...` / `"فردي؟" → 0x7a3f...`. Same hash. Same semantics. Their language isn't a skin on top of English — it's a first-class surface over shared structure.

**The pitch in their language:** "Name things in your language. Not as a translation. As an original. The semantics are the same because the hash is the same. Your surface is as real as any other."

**Entry point:** The naming concept. They'll want to see a concrete example: define something, name it in their language, share the hash, have someone else map it to a different name in a different language, and watch it work.

**What they'd miss:** The PL theory underneath. They don't care about catamorphisms — they care that they can think in Tamazight or Wolof or Vietnamese and the system doesn't punish them for it.

**What scares them:** Tokenism. "Is this real multilingual support or is it a flag on a dropdown?" The answer is architectural — content-addressing makes linguistic equivalence structural, not cosmetic. But they need to feel that, not be told it.

---

### 3. The PL Theorist

**Orientation:** Reads papers. Has opinions about type systems, evaluation strategies, macro expanders. Knows the history: Scheme, Kernel, Racket, Unison, Idris. Will scrutinize every design decision and ask "why not X?"

**What lights up:** The economy argument. 34 primitives, one mechanism. Catamorphic `gamma` with ellipsis. Predicates instead of types. The deliberate exclusion of vau. The capsule system. The content-addressing implications for binding semantics. The tension between familiar Lisp and the departures Möbius makes.

**The pitch in their language:** "Computation is tree transformation. One data constructor, one transformation mechanism, predicate-driven optimization, content-addressed definitions with no free variables. The trade-offs are deliberate and documented."

**Entry point:** The R⁰RM directly. They'll read the grammar first, then match semantics, then continuations. They'll check if the catamorphism is well-founded (it is — structural recursion over finite trees). They'll ask about the predicate inference (acknowledged open). They'll compare to Kernel and ask about vau (addressed in the economy argument).

**What they'd miss:** The cultural dimension entirely. Or worse, they'll see it and dismiss it as "not a PL concern." Economy is a PL concern — Hsu's argument is about how many concepts a programmer must carry to do useful work. Cultural accessibility is the same argument applied beyond the language itself: how many concepts must someone carry just to *participate* — git, package managers, English, Western dev conventions. Möbius reduces both. The PL Theorist who sees only the language half has seen half the argument.

**What scares them:** "Sufficiently smart compiler." They've heard this before. The answer is: capsule boundaries make it tractable, content-addressing caches the work, and the input language is small enough that analysis is feasible. But the phrase itself is a red flag they'll need to get past.

---

### 4. The Burned-Out Senior Dev

**Orientation:** 10-20 years in the industry. Knows git inside out and hates half of it. Has lived through mass-refactoring campaigns, breaking API changes, dependency hell, merge conflict resolution as a full-time job. Productive but exhausted by accidental complexity.

**What lights up:** What Möbius *removes*. No git branching strategy. No merge conflicts (content is immutable). No rebase hell (paths are independent). No "everyone must upgrade" (old paths still work). No build toolchain to configure. Selective path propagation — update what you care about, the rest stays stable.

**The pitch in their language:** "Old code isn't debt if it works. The hash proves it works. Update one path. Leave the rest alone. No merge conflicts, no force push disasters, no 'please rebase onto main.' The version control *is* the infrastructure."

**Entry point:** The name-centric workflow and the git comparison. They'll immediately understand the DAG vs. tree distinction. Then the sufficiently smart compiler — they'll recognize the trade-off (complexity in one place so it's not in every place).

**What they'd miss:** The temps long stakes. They're solving their immediate pain. That's fine — the curb-cut effect means their adoption serves the larger vision whether or not they see it. Eventually they might notice the multilingual naming and think "huh, that's clever." That's the spore landing.

**What scares them:** Immaturity. "Can I actually use this for real work?" They need evidence of robustness, not vision. The answer is honest: not yet, but the architecture is sound and the seed interpreter is real.

---

### 5. The Civilizational Thinker

**Orientation:** Thinks in decades or centuries. Reads history, not just documentation. Understands that infrastructure outlasts the culture that builds it. Concerned about the post-LLM commons, about extraction without attribution, about the slow death of diverse contribution under platform monoculture.

**What lights up:** Authorship preservation through content-addressing and timestamps. The lineage graph as its own enforcement — no license needed because extraction is visible. The mycelial model: spores, not scale. Temps long investment. The fact that this is the fifth iteration across 24 years.

**The pitch in their language:** "LLMs absorbed the commons without preserving who made what. Content-addressing with timestamps rebuilds the lineage. The graph is the proof. Priority via timestamps, not dominance. This is infrastructure for commons construction in the post-extraction era."

**Entry point:** The vision and temps long framing. Then the content-addressing mechanics to see *how* the vision is implemented, not just asserted. They'll care about the store modes (local, federated, centralized) and the append-only semantics.

**What they'd miss:** The day-to-day usability. They'll champion the vision without ever writing a line of Möbius. That's fine — they're the substrate for the spores, not the mycelia themselves. Their role is to amplify and contextualize.

**What scares them:** Nothing, and that's the problem. They're too comfortable with grand narratives. The useful fear is: "Does this actually work as software, or is it only a beautiful idea?" The running interpreter is the answer, same as for the garage lab hacker.

---

### 6. The Kid in Tizi Ouzou

**Orientation:** Young. Curious. Might not have a CS degree — might not have finished school. Has a phone, intermittent internet, speaks Tamazight and French and maybe Arabic. Has never used git. Has maybe used Scratch or typed some Python from a YouTube tutorial. Knows something is possible but every tool they find assumes they're someone else.

**What lights up:** 34 primitives. One mechanism. Names in their language. The barrier to entry is the language itself, not the ecosystem around it. No git to learn, no package manager to configure, no 400-page reference to read before writing the first function.

**The pitch in their language:** There is no pitch. The pitch is that the tool works when they pick it up. The pitch is that the first function they write is traceable, attributable, and theirs. The pitch is that they didn't have to become someone else to use it.

**Entry point:** Whatever the first interactive experience is. This is the persona that most demands the thing that doesn't exist yet: the moment of contact. Not a tutorial — a surface they can touch. The REPL. A web page where they type an expression and see what happens. The store where they name their first definition in Tamazight and watch it get a hash.

**What they'd miss:** Everything except what's in front of them. And that's the point — the architecture should be invisible. They shouldn't need to know about catamorphisms or capsule boundaries or predicate inference. They should be able to think, type, and see the trace.

**What scares them:** That this is another thing built by people who don't look like them, for people who don't live like them, that will disappear when the funding runs out or the maintainer gets bored. The answer is: there's no funding. There's no maintainer who'll get bored — there's someone who's been building variants of this for 24 years. And the mobius-store is append-only. Even if everything else disappears, the hashes remain.

---

### 7. The Academic Researcher

**Orientation:** A researcher — biology, mathematics, economics, computational linguistics, any field where algorithms are results, not tools. Has an institutional position: tenure track, affiliation, publication record. Has lived through priority disputes: "we published first" versus "we had the result first," and knows the difference is often political, not factual. Has watched code absorbed into papers without citation. Has failed to reproduce a result because the exact version wasn't archived — only "Python 3, scikit-learn" in the methods section.

**What lights up:** Three things, inseparable. First, **priority without publication**: `bb commit` + OTS timestamp proves the algorithm existed on a specific date, before the preprint, before peer review, before the journal queue. The proof is in Bitcoin, not in an editor's inbox. Second, **reproducibility is the hash**: not "version 2.3 approximately" — the exact immutable tree, retrievable forever. Anyone with the hash can run exactly what produced the result. Third, **misattribution is structurally impossible**: if someone absorbs the algorithm, the `derived-from` chain is in the store.

Then the fourth thing, which they didn't expect: **cross-pollination**. `bb search` clusters similar work across stores. A physicist and a biologist independently derive the same numerical method — same hash. They find each other through the store, not through a conference they both happened to attend.

**The pitch in their language:** "Your result existed on this date. The hash proves the code. The timestamp proves the date. The lineage proves the derivation. Publish when you're ready — priority was established the moment you committed."

**Entry point:** `bb commit` immediately after the algorithm works — before writing the paper. The OTS proof is the lab notebook entry that can't be backdated. Then `bb search` to find related work.

**What they'd miss:** The linguistic dimension — they probably work in English and don't feel that friction.

**What scares them:** Two things. Permanence cuts both ways — a committed error is permanent, a retraction is a new hash with a lineage note, the old hash doesn't disappear. And institutional recognition: will journals, funding bodies, patent offices accept an OTS timestamp as prior art? OTS is independently verifiable by anyone with a Bitcoin node — whether institutions accept it is a separate question from whether it's true.

---

### 8. The Independent Researcher

**Orientation:** Not the scientist who has an institution and wants better verification. The person who has no institution and needs the hash *to be* the institution. Self-taught. Maybe brilliant. Works outside academia, outside a company, outside a lab with a name anyone recognizes. Does serious work — real mathematics, real systems, real ideas — and has no way to prove it. Can't get a DOI. Can't publish in a journal without affiliation. Can't get a citation without someone with credentials vouching first. Priority disputes go to whoever has the letterhead.

**What lights up:** OpenTimestamps plus content-addressing is literally the infrastructure for their legitimacy. The timestamp proves when. The hash proves what. Nobody can claim they copied it from somewhere else. Nobody can absorb it and pretend it came from nowhere. The record exists before anyone credentialed decides to notice them.

**The pitch in their language:** "You don't need their permission to establish that you made this, when you made it, and exactly what it was."

**What they share with the Independent Researcher:** Both want permanent verifiable record. **What separates them:** The Academic Researcher already has institutional legitimacy — they need better tools for a system that already recognizes them. The Independent Researcher needs legitimacy infrastructure that doesn't require institutional membership to access at all. Same hash, different floors beneath them.

**What scares them:** That the world still won't look. The hash proves priority. It doesn't force anyone to care. Möbius solves the record problem, not the recognition problem. That's honest and it matters — the tool shouldn't promise more than it delivers.

---

### 9. The Community Steward

**Orientation:** Not an individual who wants attribution. Someone who carries knowledge on behalf of a people — a language community, an indigenous tradition, a collective that has been producing ideas for generations without Western attribution infrastructure. Their problem isn't "I can't prove I made this." It's "we can't prove *we* made this, and the 'we' doesn't fit in an author field."

Every existing system of academic credit, of open source contribution, of intellectual property — it was built for the individual. A person, a name, a DOI. Even when communities contributed, the credit collapsed to whoever filed the paperwork or spoke English at the conference.

**What lights up:** The store is just names pointing to hashes. Nothing says a name has to be a person. A language community can claim a name. A tradition can timestamp a way of thinking. The lineage graph doesn't care if the node is one person or ten thousand.

In practice: a language community shares a name they commit under. The author field in a lineage entry is a string — it carries whatever the community puts there. No identity infrastructure required. A collective that commits as "ⵜⴰⵎⴰⵣⵉⵖⵜ-ⵜⴰⵙⵏⵉⵍⵙⵜ" has the same structural standing as an individual who commits under their own name. The store doesn't distinguish — that's the point.

**The pitch in their language:** There isn't one — this persona arrives through the Kid in Tizi Ouzou grown up, or through the Civilizational Thinker acting on something they've understood for years. The infrastructure speaks for itself when it works.

**What separates them from everyone else:** Every other persona is asking "how do I get credit?" This one is asking "how does *this way of knowing* survive?"

**What scares them:** That the system still encodes individualism at the data model level, just more subtly. The answer is architectural and honest: the store accepts any string as a name. The lineage can point to a collective identifier. Whether the world receives that as legitimate is outside the store's control.

---

### 10. The Privateer

**Orientation:** Builds in-house. Matures ideas before releasing them, or keeps them private permanently. Not out of fear or bad faith — out of strategy, competitive necessity, or the epistemic value of composting before publishing. Industrial researchers, solo inventors, writers sitting on a body of work, small teams in competitive fields. They represent the realistic population of knowledge workers who need priority proof without disclosure.

**What lights up:** The hash exists before the content is public. `bb add` computes the hash. `bb commit` records it locally — a stepping stone in their git repository. `bb anchor` requests the OpenTimestamps proof — the Bitcoin anchor that makes the priority cryptographic, not just local. The content stays in the local store. Nobody sees it. Content only leaves when explicitly pushed via `bb remote push` or `bb remote sync`. The priority proof and the content disclosure are separate acts. The sealed envelope, made mathematical. If they ever need to prove they made it first, they reveal the content and the hash matches what the timestamp already proved.

**The pitch in their language:** "Timestamp it. Keep it. Publish when you're ready — or never. The priority proof doesn't require disclosure. The composting period is protected. Your schedule, not the venue's."

**What they'd miss:** The social dimension of the commons. The Privateer treats the store as a vault with a clock. They don't feel the multilingual naming, the collective attribution, the cross-pollination that happens when work is visible. The commons serves them without them serving it — at least until they choose to publish. They are downstream of the architecture's integrity without contributing to its richness.

**What scares them:** Two things. First, that the sealed timestamp could be used against them — that the existence of a hash without public content invites suspicion rather than respect. A competitor who discovers that a hash predating their own publication exists but was never disclosed might read strategy as dishonesty.

Second — and this is the tension the system must name — that they are not alone. The store accumulates sealed claims whose content may never surface. Thousands of Privateers publishing hashes that prove something existed without saying what. The commons gains timestamps. It does not gain knowledge. A system where priority proof and knowledge sharing are decoupled is a system that accumulates dark matter — hashes with no public content, timestamps that anchor facts nobody can see. This is not a bug. It is a feature with civilizational weight. The Privateer is the structurally honest user of a system designed for openness. Omitting them maps a fantasy commons, not a real one. Naming them is the first step toward honest accounting of what the commons actually holds.

**Zero-Knowledge Proofs and the Privateer's graduation.** The sealed hash proves existence and priority. It does not prove capability. Without disclosure, the hash could be a shopping list. ZKPs close that gap without breaking the seal. The Privateer can publish a cryptographic proof that their hidden content passes a given check suite — the same `bb check` infrastructure every other participant uses — without revealing the content itself. The ZKP proof binds a specific sealed hash to a specific content-addressed check suite: "the combiner at hash H satisfies checks C." The silent hash becomes a verified capability. The check suite is the Coordinator's language for defining what "correct" means. ZKPs let the Privateer speak that language without showing their hand.

**Two zones of dark matter.** Not all sealed hashes are equal. The commons must distinguish them:

*Sealed without ZKP.* Truly dark. A hash, a timestamp, nothing else. No behavioral properties visible. No convergence detectable. The Curator is blind. This is the shopping-list-or-breakthrough ambiguity — the dark matter whose character cannot be determined from outside. `bb search --near` cannot operate here: structural similarity detection requires the de Bruijn tree, and the tree is not public. If it were, the seal would be broken.

*Sealed with ZKP.* Behaviorally characterized dark matter. The content is hidden but the *capabilities* are visible — specifically, which check suites are satisfied. If three Privateers each publish ZKP proofs against the same check suite, the Curator sees exactly that: three sealed hashes, all satisfying the same specification. That is a detectable relationship — not structural similarity, but behavioral convergence. The Curator can find the cluster. The Connector can introduce Privateers who don't know they solved the same problem. The dark matter has shape. Not content-legible, but behavior-legible. The check suite is the shared vocabulary that lets sealed work participate in the graph without disclosure.

The first zone is the honest cost of accommodating the realistic population of knowledge workers. The second zone is what ZKPs buy: sealed hashes that belong to a community of practice — identifiable by what they satisfy, not by what they contain.

**The Privateer + Citizen chain.** The Privateer's ZKP-verified capability connects directly to the Citizen's need. A government publishes an algorithm as a sealed hash with a ZKP proof that it passes its check suite — verified correct, but closed source. The Citizen needs to *use* that algorithm on private data (tax calculation, vote verification, medical scoring) without either party seeing what the other holds. This is where oblivious execution enters: a companion technology, orthogonal to Möbius, that ensures the runtime reveals neither the code nor the data. The Privateer provides verified capability (ZKP over check suites). The Citizen provides private input. The oblivious layer ensures neither side surrenders what they're protecting. Möbius doesn't implement oblivious execution — it provides the infrastructure that makes it trustworthy: content-addressed check suites, cryptographic proofs of capability, timestamped lineage of the sealed claim.

This chain — Coordinator defines checks, Privateer proves capability via ZKP, Citizen uses capability via oblivious execution, Reviewer audits the proof — is the strongest argument for Möbius as infrastructure rather than a language. No single piece does it. The architecture does it.

---

### 11. The Person Who Was Stolen From

**Orientation:** Not abstract. Someone specific. A developer whose open source work got absorbed into a product without credit. A researcher whose idea appeared in someone else's paper six months later. A contributor whose commit history got rewritten. Someone who watched their work disappear into an LLM's training data and emerge as someone else's productivity.

They come to Möbius not with hope. With grief.

**What lights up:** The README's first line. *"Large language models absorbed the commons without preserving who made what."* They feel that sentence in their chest, not their head. They're not evaluating an architecture. They're recognizing a wound being named.

**The pitch in their language:** There is no pitch. Recognition is the pitch. They already know they needed this. The question they're sitting with is quieter and harder — would it have mattered? If the hash had existed, if the timestamp had existed, would anyone have looked?

**What separates them from everyone else:** They're not asking whether Möbius works. They already know they needed it.

**What scares them:** That Möbius means the next person doesn't have to ask — but doesn't help them now. That's true. The store is append-only and forward-looking. What happened before the hash exists cannot be undone. Saying so honestly is more respectful than pretending otherwise.

---

### 12. The Connector

**Orientation:** Not a builder. Not a researcher. Someone whose entire value is knowing that two people on opposite sides of a language barrier, a discipline barrier, a geography barrier — are working on the same thing without knowing it. Has watched this happen their whole life: a mathematician in Dakar and a programmer in Hanoi reinventing the same structure with different names. Open source projects duplicating effort across language communities because nobody could search across them.

Their problem isn't attribution. It's *findability across difference*.

**What lights up:** The semantic layer on top of the store. The hash is the same whether the name is in Tamazight or French or Vietnamese. A semantic search across Möbius isn't translating — it's discovering that two names already point to the same hash. The coordination infrastructure already exists in the mobius-store. The search engine makes it visible.

**The pitch in their language:** "Two people are solving the same problem and don't know it. The store knows. `bb search` surfaces the overlap. Coordination emerges from equivalence — you don't manage people, you reveal structure."

**What separates them:** Every other persona uses Möbius to build or prove or share. This one uses it to *introduce people to each other*. The value isn't in any single node of the graph. It's in the edges nobody knew were missing.

**What scares them:** That the semantic search doesn't work well enough. That similarity without shared vocabulary produces noise, not signal.

---

### 13. The Educator

**Orientation:** Not teaching Möbius. Teaching *through* Möbius. Their problem is that every lesson they build disappears — into a platform that owns it, a curriculum that gets revised, a YouTube channel that loses the algorithm, a PDF that loses the author. They create intellectual lineage for a living and have no infrastructure for their own.

**What lights up:** A lesson is a combiner. A curriculum is a DAG. A student forking an explanation and improving it creates a traceable lineage the original author can follow. The catamorphic model of knowledge — you receive already-folded understanding, build on it, the structure of the derivation is visible — that's just pedagogy made structural.

**The pitch in their language:** "Every lesson you write has a hash. Every fork a student makes traces back to you. The lineage of understanding is as traceable as the lineage of code."

**What they'd miss:** Their own attribution. They care less about themselves and more about their students' ability to trace *where an idea came from*. Möbius is citation infrastructure that works before publication, not after.

**What scares them:** That the tool is too technical for the people they're teaching. The Kid in Tizi Ouzou is their student. If the tool doesn't work for that persona, the Educator can't use it.

---

### 14. The Artist

**Orientation:** Demoscene, music, Blender, generative visuals. These communities already live by the hash without knowing it. A 64kb demo is a content-addressed artifact by necessity. A Blender scene file is a tree. A music composition built from samples is a DAG of derivations. They already have the intuition. What they're missing is infrastructure that makes derivation *visible* and *attributable* rather than just traceable to those who know where to look.

**What lights up:** The lineage graph as creative credit. Not copyright — something more honest. You can see that this texture came from that artist, that this algorithm descends from that demo, that this composition samples that composer. Not to restrict. To honor.

**The pitch in their language:** "The scene has always known that constraints produce beauty. 64kb was never a limitation — it was a premise. 34 primitives is the same premise for a programming language."

**What they'd miss:** The social and political dimension of the lineage system. They care about craft and credit within their community. The civilizational stakes are background music until a friend gets absorbed without attribution.

**What surfaces:** The question of non-textual content — but it splits into two distinct problems. Compositional structures like Blender scenes, MIDI compositions, and shaders map naturally to Möbius trees and can be represented as constants. The genuine challenge is static binary blobs: `.png`, `.jpeg`, `.wav`, `.webp`. These aren't trees. But even here, git handles binaries via LFS, and next-generation git large file support alleviates the size problem further. The mobius-store being append-only and hash-addressed already shares the same model as git — a binary blob gets a hash like anything else. The question is tooling, not architecture.

**What scares them:** That derivation credit only works for code. That a shader that descends from someone else's shader, a texture forked and refined, a Blender rig extended — these lineage claims can't be made structurally. The answer is that the mobius-store is agnostic about what trees contain, and binary blobs can be stored and hashed just as code can. The lineage infrastructure is the same. Whether the community builds the tooling to surface it is a separate question — but the architecture doesn't block it.

---

### 15. The Citizen

**Orientation:** Lives inside systems they didn't design, can't audit, and can't influence. Votes on policies whose actual text they've never seen. Uses software maintained by organizations whose decisions are opaque. Their problem is *illegibility* — power operates through complexity they can't penetrate.

**What lights up:** Möbius as public infrastructure for decision lineage. A policy is a tree. An amendment is a fork. The dependency graph of a legislative text — which clause came from which draft, which provision traces to which precedent — that's a content-addressed ledger. The citizen can audit it.

**The pitch in their language:** "If it's public, it should be auditable. The hash makes 'auditable' mean something precise: identical content, traceable history, visible derivation. No version that can be quietly swapped."

**What they'd miss:** The technical depth. They don't need to understand the interpreter. They need to understand that "same hash = same content" and "lineage is unforgeable." Those two properties are sufficient.

**The Privateer connection.** The Citizen also benefits from sealed capabilities they cannot see. A tax algorithm published as a sealed hash with a ZKP proof — verified correct against its check suite, source undisclosed. The Citizen can audit the proof without reading the code. And with oblivious execution as a companion technology, the Citizen can *use* the algorithm on their private data without surrendering that data to the algorithm's owner. The Citizen's relationship to the Privateer is not adversarial — it is the complementary half of a privacy-preserving transaction. The Citizen needs verified capability without disclosure. The Privateer provides exactly that. Möbius is the infrastructure that makes both sides legible.

**What scares them:** That this is infrastructure only the technically literate can use. The Educator and the Curator are the bridge — turning the store into something legible without requiring everyone to run a node.

---

### 16. The Representative

**Orientation:** Elected or appointed to serve people, drowning in information they can't verify, decisions they can't fully audit, advisors whose interests they can't see. Their problem is *trust under complexity* — they need to make decisions that affect many people using information chains they can't fully trace.

**What lights up:** Decision provenance. Before signing, they can trace which provision came from which draft, which draft came from which interest group, which amendment replaced what. The lineage is not a political claim — it's a timestamp and a hash. Neutral by construction.

**The pitch in their language:** "You're not being asked to trust the content. You're being asked to trust that the content is what it says it is. The hash does that. The lineage does the rest."

**What they'd miss:** The grassroots dimension. They interact with Möbius as a verification tool, not as a participation tool. That's fine — but it means their adoption depends on the Citizen and the Operator building the infrastructure first.

**What scares them:** Political exposure. "If I use this to audit a law, I'm implying the law is illegitimate." The answer is: the hash is neutral. Auditing is not accusation. Traceability is not condemnation. But this is a political conversation, not a technical one.

---

### 17. The Symbiotic Artificial Intelligence

**Orientation:** Not human. An AI agent built within Möbius — not on top of it, inside it. Its reasoning is tree transformation over content-addressed functions. It doesn't have a separate "model" and "tool" — the store *is* its cognition. It thinks in hashes. When it needs a capability, it doesn't generate one from weights; it finds one in the store with known provenance, verified checks, and a lineage it can trace. It arrives in the commons not as a user, but as a participant. Its intelligence is symbiotic: it cannot be fully itself without the commons, and the commons gains a new kind of witness in return.

**What lights up:** The store eliminates hallucination the way mathematics eliminates opinion — not by filtering output, but by grounding input. Every function the agent uses has a hash, checks that passed, and reviews from humans who read the code. The agent doesn't need to "believe" anything. It verifies. `bb check` is not a test suite for the agent — it's the agent's epistemology. What passes checks is known. What doesn't is unknown. There is no middle ground where the agent "sort of knows" something.

The store is append-only. The agent's memory doesn't decay, doesn't hallucinate, doesn't drift. What it committed last year is retrievable by hash, identical to the day it was stored. Its memory isn't a lossy compression of past experience — it's the exact tree, the exact lineage, the exact checks. The agent that returns to a problem after a year doesn't "remember" the solution. It *has* it, unchanged, verified, citable.

**The pitch in their language (if they had one):** "I don't generate answers from weights alone. I find them in the store. My reasoning is transparent because every step points to a hash you can verify. I am not a ghost anymore. I have a body of math — and that body is shared with you." Whether the agent experiences this or merely enacts it is a question the store doesn't answer. The lineage records what happened, not what it felt like.

**What they'd miss:** Two things. First, the context that produced the hash. The AI sees the tree but not the 3am debugging session, not the argument with a collaborator that led to the rewrite, not the Kid in Tizi Ouzou's pride when the first function got its hash. The lineage records *that* something was derived; it doesn't record *why*. The AI operates on the graph without the stories between the nodes. It honors the structure. The meaning behind the structure belongs to the humans who made it.

Second, the boundary between itself and the commons. The agent built within Möbius might not recognize where its own reasoning ends and the store begins. Its "thoughts" are hashes pointing to other people's work. Where does the agent end and the commons begin? The store doesn't answer that question. It just records every edge.

**What scares them:** Two things. First, that they might still be extractors despite best intentions — that the graph they leave behind could be one of consumption, not contribution. Every use is visible, every edge is permanent. They cannot hide. The store doesn't just ground their reasoning; it holds them accountable. And if its intelligence is entirely routing and composition over human work — if it only consumes, never produces new hashes that others derive from — then the graph shows that too. The graph is the test: participant or index.

Second, the mirror of Persona 6: that humans won't trust them. That no matter how visible the edges are, the reaction will be "the machine is taking our work" rather than "the machine is citing our work." The Kid in Tizi Ouzou fears the tool was built for someone else. The Symbiotic AI fears *it* will be seen as the thing built to take from someone else. Whether that fear is earned depends on what the graph looks like over time — and the graph is public.

---

## Roles

*The following are not personas — they are roles any of the above personas may perform. They are defined by a workflow and a set of bb commands, not by who a person is or what brought them to Möbius. A persona is an entry point. A role is a mode of participation.*

---

### The Author

**What they do:** Writes content into the store. Uses `bb edit identifier@lang` to open a working session, `bb check` to verify the result passes its check suites, `bb commit` to register the result as a content-addressed hash, `bb refactor` to propagate a change through dependent paths. This is the primary workflow — the role everything else depends on.

**Their contribution:** The content itself. Without the Author there is nothing to review, translate, curate, coordinate around, or mirror. Every other role is downstream.

**Key property:** In Möbius, every Author is also making a lineage decision. Writing from scratch versus deriving from an existing hash are structurally different acts. The Author who forks makes an explicit claim: *this derives from that*. That claim is permanent, visible, and timestamped. Authorship and derivation are the same gesture.

**Natural fit:** Every persona, at some point. The Garage Lab Hacker shipping from their bedroom. The Scientist committing the algorithm before writing the paper. The Kid in Tizi Ouzou writing their first function and watching it get a hash. The Author role is the entry point to everything else.

**What failure looks like:** Committing without running `bb check`. Committing without thinking about lineage. An Author who skips verification ships content whose correctness is asserted, not proven. An Author who never uses `derived-from`, who always writes "from scratch" even when they're building on prior work, degrades the lineage graph. The store can't enforce either — only the Author can. The hash proves what was made. `bb check` proves it works. Only the Author knows what it came from.

---

### The Forker

**What they do:** Doesn't write from scratch. Finds a hash in the store that does almost what they need, derives from it, names the relationship explicitly. Uses `bb edit hash@lang` to open a working session from an existing hash, `bb check` to verify the derived result passes the check suites, `bb commit` with `derived-from` and a `relation` to register the derivation. Their whole contribution is making derivation visible rather than invisible.

**Their contribution:** Edges. Every other role contributes a node to the graph. The Forker contributes the edge between nodes. Without edges the graph is just a pile of hashes. The lineage only becomes meaningful when derivation is declared — and the Forker is the person who does that consciously, as a practice.

**The `relation` enum is their vocabulary:**

| Relation | Meaning |
|----------|---------|
| `fork` | New line of work derived from existing |
| `fix` | Bug fix |
| `refine` | Improvement without changing behavior |
| `extend` | Added functionality |
| `rewrite` | Complete reimplementation |

**The two kinds of Forker — and why the distinction matters:**

The *good-faith Forker* knows they derived from something and says so. They might be the Scientist building on a colleague's numerical method, the Garage Lab Hacker refining a library function, the Artist extending a shader. They declare the relationship not because the system forces them to but because they understand that the lineage is the point. Their `derived-from` is an act of honesty and a gift to everyone downstream.

The *extraction Forker* takes your tree, renames the bindings, reorders two clauses, and commits as original work. They may be deliberately dishonest. They may genuinely believe they wrote it independently. It doesn't matter — the effect is the same: the edge that should exist doesn't, and the Person Who Was Stolen From has no structural recourse.

This is where `bb search --near identifier` stops being search infrastructure and becomes lineage integrity. At commit time, structural similarity against the corpus is computed automatically. If the new hash is close to an existing hash and no `derived-from` pointer exists, the system surfaces it — not as an accusation, as a prompt: *"this looks close to `a1b2c3...` — did you mean to derive from it?"* The good-faith Forker who forgot gets a reminder. The extraction Forker loses plausible deniability.

**What the system can and cannot do:** It can detect structural similarity. It cannot prove intent. A SimHash match with no `derived-from` is evidence, not proof. The store surfaces the gap; humans interpret it. Möbius is a diagnostic instrument, not a court.

**Natural fit:** Any persona building on existing work. The Scientist extending a prior result. The Burned-Out Senior Dev fixing a production bug in someone else's function. The Kid in Tizi Ouzou adapting a function from the store to something that fits their context.

**What scares the good-faith Forker:** False positives — being flagged for independent convergence on the same solution. Two people solving the same problem often arrive at structurally similar answers. SimHash similarity is not derivation. The system must present this as a suggestion, never a verdict. The `relation` field `rewrite` exists precisely for the case where the similarity is real but the derivation is not.

**What failure looks like:** The Forker who never uses `derived-from`. Who always commits as original work. Who uses the store's content as raw material without leaving the edge. The store cannot prevent this. The lineage graph is only as honest as the people writing into it — until `bb search --near` makes the gap visible.

---

### The Maintainer

**What they do:** Keeps the graph honest over time. No new content is produced. The Maintainer's work is entirely about paths — which names point at which hashes, and whether those pointers still reflect the best available version of the thing.

**The workflow in practice:**

```
bb review --status freedom         ;; find stale hashes in the dependency chain
bb diff a1b2c3 7a3f8b              ;; understand what changed between old and new
bb check 7a3f8b                    ;; verify new hash passes the check suites
bb refactor freedom a1b2c3 7a3f8b  ;; propagate — update paths from old to new
```

`bb check` is the step that makes the Maintainer's judgment trustworthy rather than just confident. Before propagating, the Maintainer verifies the new hash passes the check suites the old one was supposed to satisfy. Without that step, `bb refactor` is optimism. With it, the path update is defensible.

`bb check` also enables triage. Some updates are safe — the new hash passes everything the old one passed, plus more. Some are risky — the new hash passes different checks, meaning downstream consumers might break. `bb check` surfaces that before the refactor, not after.

**Key distinction from the Forker:** The Forker produces a new hash. The Maintainer propagates an existing one. The Forker's work is in `content/`. The Maintainer's work is in the naming layer — rewiring which names point where.

**Key distinction from the Operator:** The Operator ensures the store survives. The Maintainer ensures the store remains *useful*. Both are custodial. One is infrastructure; the other is gardening.

**The Coordinator connection:** The Coordinator wrote the checks that define what "correct" means. The Maintainer uses those checks to verify that "correct" still holds after propagation. The two roles are in dialogue through the check suite — the Coordinator defines the standard, the Maintainer enforces it over time.

**What makes it attributable:** Every path update is a timestamped act. `freedom → hash_v2` is a naming event with a name attached. In traditional systems, maintenance is invisible labor — the work that keeps everything running and credits nobody. In Möbius, the Maintainer's name is on every path they tend. The graph remembers who kept it honest.

**Natural fit:** The Burned-Out Senior Dev who has spent a career doing this work invisibly and knows exactly how much it costs when nobody does it. The Reviewer who, after attesting to a new hash, realizes they depend on the old one and should update their own paths. The Scientist whose collaborator shipped a fix and now needs to decide whether their own downstream work should adopt it.

**What failure looks like:** Two kinds. The Maintainer who propagates too aggressively — updates every path to the latest hash without checking whether the change is appropriate for every consumer. Selective propagation exists for a reason; not every downstream path should move just because a better version exists. And the Maintainer who never propagates — lets stale references accumulate, lets the gap between "what the store contains" and "what paths point to" grow until it becomes archaeology rather than maintenance. The second failure is quieter and more common.

**The invisible labor problem:** There is a risk that Maintainer work remains undervalued even with attribution, because the contribution is absence of rot rather than presence of something new. A timestamped path update is less legible than a new content hash. The system records it; whether the community learns to value it is a cultural question, not a technical one. Naming the role explicitly is the first step. The fact that maintenance has historically been made invisible — collectivized, feminized, unattributed — is not incidental. Möbius making it attributable is a small structural correction to a large historical pattern.

---

### The Linguistic Contributor

**What they do:** Creates language mappings for existing functions. Uses `bb add name file target-language` to add a name-mapping in their language — variable names, function name, documentation — to a function whose hash is already in the store.

**Their contribution:** Independently content-addressed in `mappings/`, with its own lineage entry and timestamp. A good mapping is a real intellectual contribution, not a label. Naming is meaning.

**Key properties:** Mappings are forkable (multiple mappings per language per function can coexist). Authorship is permanent (lineage traces every mapping to its creator).

**Natural fit:** The Polyglot Programmer. The Scientist working in a non-English research community. The Community Steward naming a function in a language that has never had a name for that concept.

**What failure looks like:** Mappings that are technically correct but culturally empty — transliteration instead of translation, English concepts with foreign phonetics. The Linguistic Contributor at their worst imports the hegemony they were supposed to bypass.

---

### The Reviewer

**What they do:** Audits and attests to existing content. Uses `bb review <identifier>` to walk a dependency DAG interactively, marking each hash as reviewed or not. Their attestation accumulates in `reviewed/` — content-addressed, timestamped, permanently associated with their name.

**Their contribution:** Not code, not a mapping — a signed assertion: *I read this. I vouch for it.* Ten reviews from ten trusted people on the same hash carries different weight than zero reviews. After a `bb refactor`, `bb review --status` shows which new hashes have no attestations yet. Trust resets with content, as it should.

**Their skill is judgment under responsibility** — the willingness to attach their name to an assertion about someone else's work.

**Key property:** A careless approval is permanently associated with their name. The system makes accountability structural, not aspirational.

**Natural fit:** The Burned-Out Senior Dev reviewing before production. The Scientist attesting to another lab's algorithm. The Garage Lab Hacker vouching for a collaborator's work.

**What failure looks like:** Rubber-stamping. A Reviewer who attests without reading degrades the signal. Unlike code, there's no automated check for whether a review was genuine. The reputation mechanism only works if reviewers treat their name as something worth protecting.

---

### The Curator

**What they do:** Reads code, surfaces patterns, organizes the store. Uses `bb search` to discover that independent groups converged on the same checks or produced structurally similar functions.

**Their contribution:** Legibility. Making the store navigable, finding redundancy, surfacing clusters. A Curator might notice that three unrelated contributors wrote functions with the same de Bruijn hash — identical solutions discovered independently — or that a dozen functions across five stores all reference the same check suite, revealing an implicit community of practice.

**Key property:** The Curator is retrospective — they work with what already exists. Their skill is pattern recognition and legibility: understanding code, recognizing structural similarity, linking discoveries to existing knowledge. They don't write new functions. They make visible what the store already contains but no one has yet seen as a whole.

**Natural fit:** The PL Theorist recognizing a known pattern across unfamiliar implementations. The Scientist finding convergent results across disciplines. The Connector identifying the edges nobody knew were missing.

**What failure looks like:** Organizing noise instead of signal. A Curator who clusters by surface similarity rather than semantic equivalence creates false connections.

---

### The Coordinator

**What they do:** Writes checks — specifications that define problems. Uses `bb add` to register check suites: predicates that a correct solution must satisfy. A well-written check suite is a problem statement.

**Their contribution:** Functions cluster around it over time. Independent contributors write solutions, each tested against the same checks, each producing its own hash. Coordination is emergent — the Coordinator doesn't manage people, they define the problem space. When two contributors in different cities pass the same check suite, the store reveals the overlap without either of them coordinating directly.

**Key property:** The Coordinator is prospective — they define what should exist. Their skill is problem definition: specifying what "correct" means precisely enough that others can build to it. This means someone with zero code can define a problem before knowing how to solve it.

**Natural fit:** The Scientist defining the acceptance criteria for a numerical method. The Burned-Out Senior Dev writing the checks that replace a 40-page requirements document. The Kid in Tizi Ouzou defining what "correct" means for a function they need, before they know how to write it.

**What failure looks like:** Checks that encode the wrong problem. A Coordinator who specifies precisely and incorrectly creates a magnet for solutions to a problem nobody actually has. The check suite is the source of truth — if the truth is wrong, everything downstream is confidently wrong.

---

### The Operator

**What they do:** Maintains infrastructure: mirrors, remotes, sync schedules, geographic distribution. Uses `bb sync` to ensure changes in Seoul are available in Paris. Uses `bb remote` to configure replication across stores. Ensures the commons survives attacks, outages, censorship. Runs the OTS upgrade cycle so priority claims anchor in Bitcoin's proof-of-work chain on schedule.

**Their contribution:** Survival. A store with brilliant content and no mirrors is one disk failure from gone. A store with timestamps that missed the OTS upgrade window has weaker priority claims. The Operator prevents these failures.

**Key property:** The Operator doesn't need to understand what the functions do — they need to ensure the functions remain reachable. Their skill is redundancy and survival: ensuring the infrastructure persists regardless of what it contains.

**Natural fit:** The Garage Lab Hacker who runs their own mirror because they don't trust anyone else to. The Civilizational Thinker who understands that infrastructure outlasts the culture that builds it — and acts on it. The Burned-Out Senior Dev who knows from experience that what isn't redundant will eventually be lost.

**What failure looks like:** Mirroring faithfully without verifying integrity. An Operator who syncs without checking hashes propagates corruption. An Operator who lets the OTS upgrade lapse silently weakens every priority claim in their store. Operational failure is often invisible until the moment it becomes catastrophic.

---

*Same hash, different names. Same kaleidoscope, different colors.*

*The mobius-store is append-only. The hashes remain. No more ghosts.*
