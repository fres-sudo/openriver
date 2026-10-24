# Hand-history fixtures

The parser accepts the synthetic English USD NLHE cash format represented here. Each `.txt` fixture has a neighboring `.expected.md` with hand-audited outcomes. These examples do not establish compatibility with live PokerStars exports.

Add synthetic or explicitly permitted, anonymized fixtures to cover all-ins, side pots, returns, rake, split pots, unknown cards, malformed/incomplete input, and duplicate imports. Keep any real sample out of the repository unless redistribution is permitted. The parser also enforces input size, line length, hand count, and UTF-8 bounds.

`ante_fold` checks that antes contribute to the pot without changing preflop raise-to accounting. `short_all_in_call` checks that a short call creates a main pot and a side pot with different eligible seats. Their neighboring expectation files record the hand-audited amounts.

`missing_hole_marker`, `wrong_small_blind`, and `missing_big_blind` are rejected fixtures. They check that a balanced payout does not override a missing street marker or contradictory blind posts.

`wrong_raise_increment` is rejected even though its pots and awards balance: the stated raise increment conflicts with the raise-to amount and the outstanding bet. `raked_pot` records the corresponding valid raise wording.

`check_facing_bet`, `short_call_not_all_in`, and `bet_facing_bet` are balanced but invalid betting sequences. They prove a check requires no outstanding amount, a short call requires an all-in stack, and a bet cannot follow an outstanding bet on the same street.

`same_seat_blinds` balances at 6 cents but rejects one player posting both blinds. `missing_summary` is incomplete despite balanced actions and payout. `wrong_uncalled_return` reports a balanced 5-cent total but returns only half of an unmatched 2-cent bet. `duplicate_board_card` repeats a flop card on the turn. `unsupported_currency` confirms this adapter rejects a EUR header rather than assuming USD.

`check_after_collection`, `board_after_collection`, `check_after_showdown`, `repeated_showdown`, and `showdown_after_collection` each preserve a balanced 4-cent pot. They reject events that occur after payout or showdown, and a repeated showdown marker. Each has a neighboring expected diagnostic.

`leap_day` is a valid UTC header date. `non_leap_day`, `invalid_month`, `invalid_hour`, `invalid_minute`, and `invalid_second` keep the same balanced hand but reject an impossible timestamp as `MalformedField`.
