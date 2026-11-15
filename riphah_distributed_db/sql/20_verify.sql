\set ON_ERROR_STOP on
\echo '=== Part C and data checks ==='

WITH x AS (
  SELECT count(*) AS total_rows, count(DISTINCT sid) AS unique_sids
  FROM student
)
SELECT total_rows AS reconstructed_students,
       unique_sids,
       CASE WHEN total_rows = 30000 AND unique_sids = 30000 THEN 'PASS' ELSE 'FAIL' END AS completeness_and_disjointness
FROM x;

SELECT campus, count(*) AS students,
       count(*) FILTER (WHERE cgpa < 2.00) AS cgpa_below_2
FROM student
GROUP BY campus ORDER BY campus;

SELECT count(*) AS missing_student_ids,
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS student_id_coverage
FROM generate_series(1, 30000) g(sid)
WHERE NOT EXISTS (SELECT 1 FROM student s WHERE s.sid = g.sid);

WITH e AS (
  SELECT count(*) AS total_rows,
         count(DISTINCT (sid, cid, semester)) AS unique_keys
  FROM enroll
)
SELECT total_rows AS reconstructed_enrollments,
       unique_keys,
       CASE WHEN total_rows = 240000 AND unique_keys = 240000 THEN 'PASS' ELSE 'FAIL' END AS enrollment_reconstruction
FROM e;

WITH misplaced AS (
  SELECT count(*) AS n
  FROM enroll_m e JOIN student s USING (sid) WHERE s.campus <> 'M'
  UNION ALL
  SELECT count(*)
  FROM enroll_l e JOIN student s USING (sid) WHERE s.campus <> 'L'
  UNION ALL
  SELECT count(*)
  FROM enroll_f e JOIN student s USING (sid) WHERE s.campus <> 'F'
)
SELECT sum(n) AS enroll_rows_in_wrong_home_fragment,
       CASE WHEN sum(n) = 0 THEN 'PASS' ELSE 'FAIL' END AS derived_fragment_check
FROM misplaced;

SELECT count(*) AS courses,
       count(DISTINCT cid) AS unique_course_ids,
       CASE WHEN count(*) = 900 AND count(DISTINCT cid) = 900 THEN 'PASS' ELSE 'FAIL' END AS course_reconstruction
FROM course;

WITH cross_rows AS (
  SELECT count(*) FILTER (WHERE s.campus <> c.campus) AS cross_count,
         count(*) AS total_count
  FROM enroll e
  JOIN student s USING (sid)
  JOIN course c USING (cid)
)
SELECT cross_count, total_count,
       round(100.0 * cross_count / NULLIF(total_count, 0), 2) AS cross_campus_percent,
       CASE WHEN cross_count = 12000 AND total_count = 240000 THEN 'PASS' ELSE 'CHECK' END AS five_percent_cross_campus_check
FROM cross_rows;

SELECT count(*) AS faculty_public_main,
       (SELECT count(*) FROM faculty_public_lahore) AS faculty_public_lahore,
       (SELECT count(*) FROM faculty_public_faisalabad) AS faculty_public_faisalabad,
       (SELECT count(*) FROM faculty_payroll) AS payroll_main
FROM faculty_public;


\echo
\echo 'Course distribution (expected 450 Main, 270 Lahore, 180 Faisalabad).'
SELECT campus, count(*) AS courses FROM course GROUP BY campus ORDER BY campus;

\echo
\echo 'ENROLL follows student distribution (expected 120,000 Main, 72,000 Lahore, 48,000 Faisalabad).'
SELECT s.campus AS student_home_campus, count(*) AS enrollment_rows
FROM enroll e JOIN student s USING (sid)
GROUP BY s.campus ORDER BY s.campus;

\echo
\echo 'Faculty campus distribution (expected 600 Main, 360 Lahore, 240 Faisalabad).'
SELECT campus, count(*) AS faculty_rows
FROM faculty_public GROUP BY campus ORDER BY campus;

\echo
\echo 'Replica content comparison from Main.'
SELECT
  (SELECT count(*) FROM faculty_public p
   FULL JOIN faculty_public_lahore l USING (fid)
   WHERE p.fid IS NULL OR l.fid IS NULL OR
         (p.name, p.dept, p.campus, p.phone, p.email) IS DISTINCT FROM
         (l.name, l.dept, l.campus, l.phone, l.email)) AS mismatches_lahore,
  (SELECT count(*) FROM faculty_public p
   FULL JOIN faculty_public_faisalabad f USING (fid)
   WHERE p.fid IS NULL OR f.fid IS NULL OR
         (p.name, p.dept, p.campus, p.phone, p.email) IS DISTINCT FROM
         (f.name, f.dept, f.campus, f.phone, f.email)) AS mismatches_faisalabad;

SELECT 'All counts above should match the stated synthetic dataset sizes.' AS note;
