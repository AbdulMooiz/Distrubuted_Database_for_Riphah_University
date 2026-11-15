\set ON_ERROR_STOP on
\echo '=== Q1 at Lahore: campus and CGPA predicates should prune five minterm fragments ==='
EXPLAIN (ANALYZE, VERBOSE, COSTS OFF)
SELECT sid, name, program, campus, cgpa
FROM student_l_low
WHERE campus = 'L' AND cgpa < 2.00
ORDER BY sid
LIMIT 20;

\echo 'This is the localized Q1 rewrite: only STUDENT_L_LOW is read at Lahore.'
SELECT sid, name, program, campus, cgpa
FROM student_l_low
WHERE campus = 'L' AND cgpa < 2.00
ORDER BY sid
LIMIT 20;

\echo
\echo '=== Q2 at the Lahore student home campus: ENROLL_L is local ==='
\echo 'The course join may contact another campus for a cross-campus elective.'
SELECT e.sid, e.cid, c.title, e.semester, e.grade
FROM enroll_l e
JOIN course c ON c.cid = e.cid
WHERE e.sid = 15001
ORDER BY e.semester, e.cid;

\echo
\echo '=== Q4: local faculty directory replica ==='
SELECT fid, name, dept, email FROM faculty_directory ORDER BY fid LIMIT 5;
