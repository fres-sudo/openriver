# Missing hole-card marker expectation

Hand 1013 is rejected with `InvalidHand`. Betting begins before the required `*** HOLE CARDS ***` marker, so the adapter cannot trust its street boundary. The neighboring normal hand remains accepted.
