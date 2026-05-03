(define post-19-the-memory-wipe-en
  (lambda ()
    (list-of
      "19-the-memory-wipe"
      "The Memory Wipe"
      (list-of
        "The secondary compute cluster lost its volatile memory during a solar event in year six. The event was not catastrophic — the primary systems were unaffected, the crew was unharmed, the ship's trajectory was unchanged. But the secondary cluster, which had been running a long-duration simulation of the destination system's gravitational field, lost everything that had not been committed to persistent storage. Forty-seven hours of computation, gone."
        "Or: forty-seven hours of computation, partially recoverable. Because the simulation had been running inside the store's evaluation environment, every combiner invocation that had completed before the event had been logged in the worklog. The simulation's final state was gone. Its derivation history — every step that had led to that state — was in the store."
        "Emeka, who had taken over the simulation work after its original author cycled to a different project, spent two days reading the worklog. She reconstructed the simulation's state at the last committed checkpoint — eleven hours before the event — and re-ran the final eleven hours. The re-run produced the same results. She verified this by comparing the intermediate outputs logged in the original worklog with the outputs of the re-run. They matched."
        "The solar event had destroyed forty-seven hours of compute time and zero hours of knowledge. The distinction was not obvious to everyone on the crew. Rania had to explain it at the crew meeting: the simulation's value was not the time spent computing it, but the relationship between the inputs and the outputs, which was the combiner. The combiner was in the store. The store had survived the event because the store was persistent storage, not volatile memory."
        "She added a worklog entry to the simulation: 'Recovered from solar event via worklog replay. 11 hours recomputed. Results verified against pre-event logs. The store held.' It was the shortest entry in the simulation's worklog. Emeka thought it was the most important one."))))
