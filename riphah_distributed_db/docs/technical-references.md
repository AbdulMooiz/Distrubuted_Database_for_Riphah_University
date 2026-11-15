# Technical references

- PostgreSQL 16, `postgres_fdw`: https://www.postgresql.org/docs/16/postgres-fdw.html
  - Describes remote transaction management, remote query optimization and the limitation that `postgres_fdw` does not prepare remote transactions for two-phase commit.
- PostgreSQL 16, Two-Phase Transactions: https://www.postgresql.org/docs/16/two-phase.html
  - Describes PostgreSQL's two-phase transaction commands and their intended use by an external transaction manager.

## Semijoin byte condition

Let `S` be the Main campus course fragment, `K` the number of distinct course IDs sent from Faisalabad, `wK` the byte width of one course ID, `M` the number of matching course tuples returned, and `wS` the average tuple width in `S`.

- Full transfer: `Cost_full = |S| × wS`
- Semijoin transfer: `Cost_semi = K × wK + M × wS`
- Semijoin wins on bytes when `M / |S| < 1 - (K × wK) / (|S| × wS)`

The SQL demo uses a 4-byte integer for `CID`. Its byte model does not include round-trip latency, message framing or query planning overhead.
