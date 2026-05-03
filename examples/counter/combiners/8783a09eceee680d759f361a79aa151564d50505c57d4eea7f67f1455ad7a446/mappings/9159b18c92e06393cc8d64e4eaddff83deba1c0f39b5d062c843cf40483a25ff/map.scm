((doc . "clicker-state: application-state factory for the clicker web app.\nCalled once at server start with no arguments.\nReturns a mutable box holding a vector:\n  #(score total n0 c0 n1 c1 n2 c2)\n  score  — spendable score\n  total  — lifetime total earned (never decremented)\n  n0 c0  — auto-clicker (+1/click): count, current cost\n  n1 c1  — rocket     (+5/click): count, current cost\n  n2 c2  — solar farm (+20/click): count, current cost")
 (function . "8783a09eceee680d759f361a79aa151564d50505c57d4eea7f67f1455ad7a446")
 (language . "en")
 (mapping . ((0 . "clicker-state"))))