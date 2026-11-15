\set ON_ERROR_STOP on
\echo '=== Part D: allocation and replication ==='
SELECT 'Main' AS site, 'STUDENT_M_LOW / STUDENT_M_OTHER' AS fragments
UNION ALL SELECT 'Lahore', 'STUDENT_L_LOW / STUDENT_L_OTHER'
UNION ALL SELECT 'Faisalabad', 'STUDENT_F_LOW / STUDENT_F_OTHER'
UNION ALL SELECT 'Main', 'COURSE_M, ENROLL_M, FACULTY_PAYROLL'
UNION ALL SELECT 'Lahore', 'COURSE_L, ENROLL_L'
UNION ALL SELECT 'Faisalabad', 'COURSE_F, ENROLL_F'
UNION ALL SELECT 'All three', 'FACULTY_PUBLIC replica';

\echo
\echo 'Directory replica counts (all should be 1,200).'
SELECT (SELECT count(*) FROM faculty_public) AS main_copy,
       (SELECT count(*) FROM faculty_public_lahore) AS lahore_copy,
       (SELECT count(*) FROM faculty_public_faisalabad) AS faisalabad_copy;

\echo
\echo 'Change one public phone number. The trigger sends the update to both remote copies.'
SELECT phone AS old_phone FROM faculty_public WHERE fid = 1 \gset
UPDATE faculty_public SET phone = '+92 51 9999999' WHERE fid = 1;
SELECT 'Main' AS site, phone FROM faculty_public WHERE fid = 1
UNION ALL SELECT 'Lahore', phone FROM faculty_public_lahore WHERE fid = 1
UNION ALL SELECT 'Faisalabad', phone FROM faculty_public_faisalabad WHERE fid = 1;

\echo
\echo 'Restore the original test value.'
UPDATE faculty_public SET phone = :'old_phone' WHERE fid = 1;

\echo
\echo 'Read/write estimate: 2,000 Q4 reads/day. If evenly split, about 1,333 are remote without replicas.';
\echo 'Each public update needs two remote writes. With equal message cost, break-even is about 667 updates/day.';
\echo 'The brief gives no update frequency, so this is an explicit assumption, not a measured workload fact.';
