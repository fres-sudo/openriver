# Wrong uncalled return expectation

Hand 1022 is rejected with `InvalidHand`. The reported 5-cent pot and award balance, but Ada's unmatched 2-cent flop bet is returned as only 1 cent. The return must equal the full unmatched street contribution.
