# ZETAGOLD — News Risk Gate

## Operational policy

For a scheduled news event at time T (MT4 server time):

- T-30 min: block creation of new orders/cycles.
- T-30 to T-5: an already active basket is allowed to continue.
- T-5: execute RED = FLAT for ZETAGOLD-managed exposure.
- T to T+20: remain FLAT and block new orders.
- T+20: normal order admission resumes.

The News Gate does not modify direction logic, recovery calculations, trailing rules, or the existing execution primitives. It acts at the central new-order admission boundary and invokes the existing close/delete primitives for the T-5 FLAT action.

## Schedule input

P02B_07_NewsSchedule accepts exact MT4 server timestamps separated by semicolons:

2026.09.25 15:30|USD|HIGH|CPI;2026.09.25 17:00|USD|HIGH|FOMC

Currency, impact and title are informational.

## Telegram / external bridge

P02B_08_NewsCommandFile defaults to ZETAGOLD_NEWS.txt.

The EA reads this file from MT4 FILE_COMMON when P02B_09_NewsFileEnabled=true.

One event per line:

YYYY.MM.DD HH:MI|CURRENCY|IMPACT|TITLE

Example:

2026.09.25 15:30|USD|HIGH|CPI

The external Telegram process can overwrite this file with the current day's schedule. The EA refreshes it every P02B_10_NewsFileRefreshSeconds.

## Safety boundary

The external bridge supplies data only. It does not directly execute orders. The EA remains responsible for:

1. determining the current news state;
2. blocking new order admission;
3. executing RED/FLAT at T-5;
4. keeping the system blocked until T+20.

The Telegram adapter itself is intentionally outside this repository because its source is not part of sezinando/ZETAGOLD.
