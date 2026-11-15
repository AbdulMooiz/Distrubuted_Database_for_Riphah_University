\set ON_ERROR_STOP on
\echo '=== Part C: Status fragmentation trap ==='
SELECT status, count(*) AS rows
FROM student
GROUP BY status
ORDER BY status;

\echo
\echo 'If split by Status, these three fragments reconstruct STUDENT because Status is constrained to three values.'
WITH status_fragments AS (
    SELECT sid FROM student WHERE status = 'Active'
    UNION ALL
    SELECT sid FROM student WHERE status = 'Graduated'
    UNION ALL
    SELECT sid FROM student WHERE status = 'Suspended'
)
SELECT count(*) AS rows_after_union_all,
       count(DISTINCT sid) AS distinct_sids,
       CASE WHEN count(*) = 30000 AND count(DISTINCT sid) = 30000
            THEN 'PASS: complete and disjoint' ELSE 'FAIL' END AS status_partition_check
FROM status_fragments;

\echo
\echo 'Quality warning: Q1 has no Status predicate, so it must inspect every Status fragment at the campus.'
\echo 'Q2 also has no Status predicate and is much more frequent (5,000/day).'
\echo 'Only Q6 directly benefits from an Active-only fragment. Correctness does not guarantee good workload fit.';
