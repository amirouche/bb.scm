(define post-02-the-hacker-en
  (lambda ()
    (list-of
      "02-the-hacker"
      "The Garage Lab Hacker"
      (list-of
        "Yusuf arrived at the Hold with a duffel bag, a soldering iron, and the conviction that any problem solvable in theory was solvable before breakfast. He was not an official member of the engineering team. He had been invited because he had already built a content-addressed store in a weekend, for reasons no one fully understood, and it worked."
        "His workspace was a corner of the maintenance bay where the smell of machine oil never quite left. He strung a cable from the structural sensor array to a Raspberry Pi cluster he had assembled from spares, and called it his testbed. The Hold's official systems team regarded him with the particular wariness reserved for people who produce results without filing tickets."
        "The first problem Yusuf solved was bootstrapping. A content-addressed store needs a way to register its own primitives — but those primitives are not yet in the store when you start. He wrote the primitive table on paper first, then transcribed it into a file that the evaluator could load before the store was consulted. The paper still existed, taped to the wall above his Pi cluster. The team called it the Rosetta Stone."
        "He did not name his combiners carefully at first. He called them things like 'q', 'qq', 'qqq'. When Amara, the Polyglot Programmer, found out, there was a brief and spirited disagreement. Yusuf's position was that names were presentation, not logic, and the hash was what mattered. Amara's position was that a system no one could read was a system no one would trust. They were both right. The naming system they designed together was the one that shipped."
        "On the eighteenth day of the first rotation, the Pi cluster's power supply failed. Three hours of work were in volatile memory. Yusuf retrieved it from the hash log, because every evaluation had been committed. He told no one. He just kept working."))))
