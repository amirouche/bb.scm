(define post-04-the-senior-en
  (lambda ()
    (list-of
      "04-the-senior"
      "The Burned-Out Senior Dev"
      (list-of
        "Marcus had been building software for twenty-three years. He had survived four reorgs, two acquisitions, a migration from on-premise to cloud that took three years and produced no discernible improvement, and a distributed systems incident that he still thought about in the middle of the night. He came to the Hold because he was, in his own words, trying one more thing before he stopped trying things."
        "He spent his first week reading the store design documents without commenting on them. This made the junior engineers nervous. On the eighth day he said, during a review session: 'I want to know what's not in here.' The room went quiet. He clarified: 'Every system I've seen has something missing at the center that everyone pretends isn't missing. I want to know what this one's pretending about.'"
        "What was not in the store, as designed, was a way to express that something had been deliberately left out. You could add. You could derive. You could retract by derivation. But there was no primitive for 'this is outside scope by design.' Marcus spent a week arguing that this was a feature, not a gap. He lost the argument but the discussion produced the attestation system — a way to record that a reviewer had considered a combiner and chosen not to extend it, for reasons now in the worklog."
        "He was the first person to mark a combiner as reviewed and add a note that read: 'I don't like this but it's the right tradeoff.' The note was not in the hash. The hash was the logic. The note was in the worklog, timestamped, attributed to his author key. Twenty years later, a crew member on a ship he would never board would read that note and understand why a design decision that looked wrong at first glance was actually correct."
        "Marcus stayed for two rotations. He said the Hold was the first environment he had worked in where the absence of a feature was a documented position rather than an undocumented assumption. He meant it as a compliment. It was."))))
