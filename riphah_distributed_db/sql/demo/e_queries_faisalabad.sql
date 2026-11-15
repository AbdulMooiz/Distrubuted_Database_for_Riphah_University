\set ON_ERROR_STOP on
\echo '=== Q3 at Faisalabad: class roster for a Faisalabad course ==='
\echo 'ENROLL follows student home campus, so a complete roster can read ENROLL_M, ENROLL_L and ENROLL_F.'
SELECT sid, name, student_campus, semester, grade
FROM class_roster
WHERE cid = 722
ORDER BY sid
LIMIT 20;
