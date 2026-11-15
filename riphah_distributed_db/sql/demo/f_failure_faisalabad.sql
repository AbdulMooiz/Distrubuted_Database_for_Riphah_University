\echo '=== Faisalabad site after its network link is disconnected ==='
\echo 'Q1 local low-CGPA student query should still work.'
SELECT count(*) AS q1_local_rows
FROM student_f_low WHERE campus = 'F' AND cgpa < 2.00;

\echo
\echo 'Q2 local enrollment rows for one Faisalabad student should work.'
SELECT sid, cid, semester, grade
FROM enroll_f
WHERE sid = 25000
ORDER BY semester, cid;

\echo
\echo 'Choose a Faisalabad student whose eight courses are all Faisalabad courses, then show local titles.'
SELECT e.sid AS local_only_sid
FROM enroll_f e
GROUP BY e.sid
HAVING count(*) = 8 AND bool_and(e.cid BETWEEN 721 AND 900)
ORDER BY e.sid
LIMIT 1 \gset
SELECT e.sid, c.title, e.semester, e.grade
FROM enroll_f e JOIN course_f c USING (cid)
WHERE e.sid = :local_only_sid
ORDER BY e.semester, e.cid;

\echo
\echo 'EXPECTED FAILURE: cross-campus course lookup needs remote course fragments.'
SELECT e.sid, c.title, e.semester, e.grade
FROM enroll_f e JOIN course c USING (cid)
WHERE e.sid = 25000;

\echo
\echo 'EXPECTED FAILURE: a complete class roster needs all three ENROLL fragments.'
SELECT count(*) AS complete_roster_rows FROM class_roster WHERE cid = 722;

\echo
\echo 'Local partial roster works but misses students enrolled from the other home campuses.'
SELECT count(*) AS local_partial_roster_rows FROM enroll_f WHERE cid = 722;

\echo
\echo 'Q4 local faculty directory replica should work.'
SELECT count(*) AS local_directory_rows FROM faculty_public;

\echo
\echo 'Q5 payroll is not stored at Faisalabad by design.'
SELECT to_regclass('faculty_payroll') AS payroll_relation_at_faisalabad;

\echo
\echo 'EXPECTED FAILURE: Q6 needs partial aggregates from Main and Lahore.'
SELECT program, count(*) FROM student GROUP BY program;
