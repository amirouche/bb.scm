(define post-10-the-check-en
  (lambda ()
    (list-of
      "10-the-check"
      "The Check"
      (list-of
        "Three weeks before the departure window, the Hold ran its final integration test. Not a software test — a full-environment test. Every system that would travel on the ship was run simultaneously for seventy-two hours at the load levels the mission profile predicted for the first year of cruise phase. The software team's job was to watch the store."
        "They watched it the way you watch a person you trust but cannot fully see: looking for changes in behavior rather than evidence of failure. Every combiner that was called logged its call in the worklog. Every check that ran logged its result. At the end of seventy-two hours, the team had a complete record of what the system had done, in the order it had done it, traceable to the exact version of each combiner involved."
        "Two anomalies surfaced. One was a timing issue in the network routing layer, found in the logs and fixed before the test ended. The other was stranger: a combiner that had been replaced six months earlier was still being called by a subsystem that had not been updated to use the new version. Both versions were correct. Both were in the store. The subsystem was using the old one because no one had told it about the new one."
        "The fix was not to delete the old combiner — that was not possible; the store was append-only. The fix was to add a derivation edge from the old hash to the new hash, mark the old hash as superseded, and update the subsystem's manifest. The subsystem then resolved the name to the new version at load time. The old version remained, documented, retrievable, its worklog intact."
        "On the last day before the departure window locked, Yusuf ran the full check suite one more time. All checks passed. He added a worklog entry: 'Ready.' Fatou added hers: 'Ready.' Lylia, who had stayed up through the night running the environmental sensor integration, added: 'Ready, I think.' The store recorded all three. The ship was ready. Whether the crew was ready was a different kind of question."))))
