\echo '=== Main while Faisalabad is unreachable ==='
\echo 'Q5 payroll at Main should continue to work.'
SELECT count(*) AS payroll_rows_at_main FROM faculty_payroll;

\echo
\echo 'EXPECTED FAILURE: a Main directory update cannot reach every replica.'
SELECT phone AS before_phone FROM faculty_public WHERE fid = 1 \gset
UPDATE faculty_public SET phone = '+92 51 0000000' WHERE fid = 1;
SELECT phone AS after_phone FROM faculty_public WHERE fid = 1;
\echo 'The local value should remain unchanged because the trigger update failed.'
