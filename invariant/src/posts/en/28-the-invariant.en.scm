(define post-28-the-invariant-en
  (lambda ()
    (list-of
      "28-the-invariant"
      "The Invariant"
      (list-of
        "What does a system need to be true, always, regardless of what happens to it? This was the question that Fatou put to the crew at the annual technical meeting in year nine of the voyage. They had been in the silence for two years. The meeting had the particular quality of meetings held by people who have accepted that their situation is permanent until proved otherwise."
        "The answers came slowly, one at a time, and Fatou wrote them in a document combiner that everyone could see on the common room display. The store's append-only structure: whatever is added cannot be removed, only superseded by derivation. The hash as identity: the thing is the same as what it was if and only if the hash matches. The worklog as continuity: nothing is lost that was committed, even if the process that produced it is gone."
        "Rania added one that surprised the room: 'A correct check that passes today will pass tomorrow on the same combiner.' No one had stated this explicitly before. It followed from the immutability of hashes — a combiner with a given hash would always produce the same output for the same input, so a check that tested a specific output for a specific input would always give the same result on that combiner. This was not a property they had designed for. It was a consequence of what they had designed."
        "The list grew to nine items. Fatou added a tenth: 'The store is present where it is deployed. Earth being unreachable does not make the store less present.' She read this aloud. The room was quiet for a moment. Then Chen said: 'That's why we called it an invariant.' Someone else said: 'Is that why we called it that?' Chen said he thought so. No one was certain."
        "The document was titled 'The Invariant' and registered in the store. It was the most-read document in the ship's store for the remainder of the voyage. Every crew member who joined after year nine read it first, as an introduction, before reading anything else. It told them what was true, always. That was enough to start."))))
