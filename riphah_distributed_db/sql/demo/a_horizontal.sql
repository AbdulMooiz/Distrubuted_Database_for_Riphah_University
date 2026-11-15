\set ON_ERROR_STOP on
\echo '=== Part A: horizontal fragmentation and derivation ==='
\echo 'Minterms: (Campus=M/L/F) AND (CGPA<2.00 or CGPA>=2.00).'
\echo 'Impossible minterms combining two campus values are removed.'

SELECT 'student_m_low' AS fragment, count(*) FROM student_m_low
UNION ALL SELECT 'student_m_other', count(*) FROM student_m_other
UNION ALL SELECT 'student_l_low', count(*) FROM student_l_low
UNION ALL SELECT 'student_l_other', count(*) FROM student_l_other
UNION ALL SELECT 'student_f_low', count(*) FROM student_f_low
UNION ALL SELECT 'student_f_other', count(*) FROM student_f_other
ORDER BY fragment;

\echo
\echo 'A Lahore students elective at Faisalabad stays in ENROLL_L because ENROLL follows the student.'
SELECT e.sid, s.campus AS student_home, c.campus AS course_campus,
       e.cid, c.title, e.semester, e.grade
FROM enroll_l e
JOIN student s ON s.sid = e.sid
JOIN course c ON c.cid = e.cid
WHERE s.campus = 'L' AND c.campus = 'F'
ORDER BY e.sid, e.cid
LIMIT 1;

\echo
\echo 'Q3 for one Faisalabad course must inspect student-derived ENROLL fragments from all campuses.'
SELECT 722 AS course_id,
       (SELECT count(*) FROM enroll_m WHERE cid = 722) AS from_main_students,
       (SELECT count(*) FROM enroll_l WHERE cid = 722) AS from_lahore_students,
       (SELECT count(*) FROM enroll_f WHERE cid = 722) AS from_faisalabad_students,
       (SELECT count(*) FROM enroll WHERE cid = 722) AS total_roster_rows;
