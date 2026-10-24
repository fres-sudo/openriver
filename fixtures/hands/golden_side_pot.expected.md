# Golden side-pot accounting

This is synthetic PokerStars-like text, not a claim of room compatibility. Amounts
are USD cents. The board is 2c 7d 9h Js 3c. Ada shows As Ah and wins the
main pot with a pair of Aces; Bo shows Kc Kd and wins the side pot with a
pair of Kings over Cy's Qs Qh.

| Seat | Starting stack | Gross paid | Returned | Net contribution | Award | Ending stack |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ada | 100 | 100 | 0 | 100 | 300 | 300 |
| Bo | 200 | 200 | 0 | 200 | 200 | 200 |
| Cy | 300 | 300 | 100 | 200 | 0 | 100 |

The main pot is 100 × 3 = 300, eligible seats 1, 2, 3. The side pot is
(200 − 100) × 2 = 200, eligible seats 2, 3. The unmatched 100 returns to
Cy and never enters a pot. Net contributions 500 equal awards 500 plus rake 0.

Canonical actions, in order: seat 1 small blind 1; seat 2 big blind 2;
seat 3 raise-to 300; seat 1 call 99; seat 2 call 198; seat 3 return 100.
The raise-to amount is the total seat 3 paid on this street.
