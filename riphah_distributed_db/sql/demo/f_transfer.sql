\set ON_ERROR_STOP on
\echo '=== Part F: campus transfer demonstration at Main ==='
SELECT sid, name, campus, cgpa FROM student WHERE sid = 100;
SELECT (SELECT count(*) FROM enroll_m WHERE sid = 100) AS enroll_main,
       (SELECT count(*) FROM enroll_l WHERE sid = 100) AS enroll_lahore,
       (SELECT count(*) FROM enroll_f WHERE sid = 100) AS enroll_faisalabad;

CALL transfer_student(100, 'L');
SELECT sid, name, campus, cgpa FROM student WHERE sid = 100;
SELECT (SELECT count(*) FROM enroll_m WHERE sid = 100) AS enroll_main,
       (SELECT count(*) FROM enroll_l WHERE sid = 100) AS enroll_lahore,
       (SELECT count(*) FROM enroll_f WHERE sid = 100) AS enroll_faisalabad;
SELECT count(*) AS same_enrollment_count_seen_globally FROM enroll WHERE sid = 100;

\echo
\echo 'Move the student back to restore the seed data.'
CALL transfer_student(100, 'M');
SELECT sid, name, campus FROM student WHERE sid = 100;
