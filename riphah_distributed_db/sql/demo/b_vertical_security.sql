\set ON_ERROR_STOP on
\echo '=== Part B: vertical fragmentation at Lahore ==='
\echo 'Q4 reads the local FACULTY_PUBLIC copy. No WAN read is needed.'
SELECT fid, name, dept, email FROM faculty_public ORDER BY fid LIMIT 5;
SELECT count(*) AS local_public_rows FROM faculty_public;
\echo
\echo 'Payroll is intentionally absent at Lahore:'
SELECT to_regclass('faculty_payroll') AS payroll_relation_at_lahore;
\echo 'Run b_view_comparison.sql at Main to inspect the public/payroll join and permissions.';
