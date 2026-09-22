# Explicit Direction + Order Comment — ZETAGOLD v0.122

Base: refactor/v0.116-engine12-parity.

- P01_05_TradeDirectionMode: BOTH (default), ONLY_BUY, ONLY_SELL.
- BOTH preserves the v0.116 two-sided model.
- Direction control is manual; no Intelligence/predictive dependency.
- Direction gating applies to first admission, keep-alive and recovery-entry creation.
- P01_04_StrategyComment: optional, default blank.
- The strategy prefix is never truncated.
- Technical order tags are compacted to fit MT4's 31-character comment limit.
- Example: AW Recovery Average | R1 BUY.
