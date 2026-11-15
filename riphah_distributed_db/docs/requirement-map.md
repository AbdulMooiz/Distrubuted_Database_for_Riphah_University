# Requirement map and review checklist

This is an implementation map, not the D1 report.

| Assignment item | Implemented in | What to check |
|---|---|---|
| A1 minterms and STUDENT fragments | `sql/init/*.sql`, `demo/a_horizontal.sql` | Six campus by CGPA fragments and campus counts |
| A2 derived ENROLL | `10_seed_and_distribute.sql`, `demo/a_horizontal.sql` | Every enrollment row is stored with its student's campus |
| A3 cross-campus elective | `demo/a_horizontal.sql` | Lahore student's elective remains in ENROLL_L |
| B4 attribute usage matrix | `docs/attribute-usage-matrix.md` | FID and Name support both workloads; public and payroll attributes split |
| B5 and B6 vertical split/security | `sql/init/*.sql`, `demo/b_vertical_security.sql`, `b_view_comparison.sql` | Payroll is Main-only; public directory is replicated |
| C7 correctness | `sql/20_verify.sql` | Completeness, reconstruction, disjointness |
| C8 Status trap | `demo/c_status_trap.sql` | Correct but not a good fit for Q1/Q2 |
| D9 allocation | `demo/d_allocation_replication.sql` and README | Every fragment has a site |
| D10 replication trade-off | `demo/d_allocation_replication.sql` | 2,000 Q4/day; break-even estimate states assumptions |
| E11 Q1 localization | `demo/e_queries_lahore.sql`, `demo/e_queries_faisalabad.sql`, `demo/e_queries_main.sql` | Run at Lahore and inspect EXPLAIN output |
| E12 Q6 partial aggregation | `demo/e_queries_main.sql` | Look for remote aggregate work in EXPLAIN VERBOSE |
| E13 semijoin | `demo/e_semijoin.sql` | Both win and lose examples plus break-even condition |
| F transfer | `demo/f_transfer_procedure.sql`, `demo/f_transfer.sql` | Move student and enrollments, then restore seed data |
| F link failure | `scripts/failure_demo.ps1`, failure SQL files | Local work continues; remote dependent work fails |
| F 40% electives | README design section | Explain why course replication becomes more attractive |

## Review items before submission

1. Run the project on the team's own Docker installation. This build environment did not have Docker or `psql`, so a live PostgreSQL execution could not be performed here.
2. Confirm the three campus counts, 240,000 ENROLL rows and exactly 12,000 cross-campus elective rows using `20_verify.sql`.
3. Inspect the Q1 and Q6 `EXPLAIN` output on the actual PostgreSQL image. Keep the output for the D1 report.
4. Run the failure demo and confirm the PowerShell script reconnects Faisalabad even when expected SQL errors occur.
5. Capture the actual test outputs/screenshots. Do not copy invented output into the report.
6. Each group member should be able to explain the fragmentation choice, the replica trigger, the transfer limitation and the semijoin break-even formula.


## Correctness arguments for D1

- Completeness: every student has exactly one campus in `{M, L, F}` and exactly one of `CGPA < 2.00` or `CGPA >= 2.00`, so every STUDENT row belongs to one of the six minterms.
- Disjointness: the campus predicates are mutually exclusive, and the low/other CGPA predicates are mutually exclusive. The fragments therefore cannot share a SID.
- Reconstruction: `STUDENT` is reconstructed with `UNION ALL` over all six fragments. Because the fragments are disjoint, `UNION ALL` does not introduce duplicates and avoids the sorting/deduplication cost of `UNION`.
- Derived ENROLL completeness: every ENROLL row has a SID that identifies one student's home campus. A semijoin with the union of the two STUDENT minterms for that campus places the row in exactly one of ENROLL_M, ENROLL_L or ENROLL_F.
- COURSE completeness: each course is assigned to exactly one offering campus, so the three campus fragments reconstruct COURSE with `UNION ALL`.
