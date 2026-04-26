(define post-07-the-coordinator-en
  (lambda ()
    (list-of
      "07-the-coordinator"
      "The Coordinator"
      (list-of
        "No one had specifically hired Fatou to coordinate the Hold's software integration work. The role had existed as a gap in the organizational chart for the first three months, which meant that Fatou — who had a background in systems engineering and a gift for watching things fall apart before they did — filled it by showing up to every meeting and writing down what people agreed to."
        "Her first systematic contribution was the check suite. The store had a mechanism for attaching verification procedures to combiners — small programs that tested invariants and reported pass or fail — but no one had written checks for the base library. Fatou spent two weeks reading every combiner in the base library, writing a check for each one, and then running the full suite every morning before the team meeting. She filed issues for anything that failed."
        "The checks were not novel mathematics. They were the kind of thing a careful programmer would verify by hand: does the empty list behave correctly, does string concatenation preserve length, does the escape function handle the edge cases. What made them valuable was that they ran. Every day. Against the actual store, not a mock."
        "When a combiner was edited — by Yusuf, by Lylia, by anyone — the checks ran again. The store's immutability meant that editing a combiner produced a new hash, and the new hash carried a new set of checks. Fatou tracked which checks had been written for which versions. When a version was superseded, the checks stayed attached to its hash. You could always verify the old version still behaved the way it once had."
        "She trained three other crew members to write checks before the departure. She wrote a guide called 'What a Check Is For,' which was four paragraphs long and contained no code. The guide was added to the store under a hash. It was the first natural-language document registered in the system, and it survived the voyage."))))
