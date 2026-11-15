\set ON_ERROR_STOP on
\echo '=== View comparison at Main ==='
\echo 'The logical view hides the join from users. The sensitive payroll relation is still physically separate.'
SELECT fid, name, dept, campus, phone, email, salary, bank_account
FROM faculty_full
ORDER BY fid
LIMIT 5;

\echo
\echo 'Directory readers receive only the public relation. Payroll is a separate table and is not granted to them.'
SELECT has_table_privilege('directory_reader', 'faculty_public', 'SELECT') AS directory_reader_can_read_public,
       has_table_privilege('directory_reader', 'faculty_directory', 'SELECT') AS directory_reader_can_read_directory_view,
       has_table_privilege('directory_reader', 'faculty_payroll', 'SELECT') AS directory_reader_can_read_payroll,
       has_table_privilege('payroll_reader', 'faculty_payroll', 'SELECT') AS payroll_reader_can_read_payroll;
