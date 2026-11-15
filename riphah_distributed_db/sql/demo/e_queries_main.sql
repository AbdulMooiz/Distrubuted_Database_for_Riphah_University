\set ON_ERROR_STOP on
\echo '=== Q5 at Main only: vertical public/payroll reconstruction ==='
SELECT name, salary, bank_account FROM faculty_full ORDER BY fid LIMIT 5;

\echo
\echo '=== Q6: compute partial counts by program at each fragment, then sum at Main ==='
EXPLAIN (VERBOSE, COSTS OFF)
SELECT program, sum(n)::bigint AS active_students
FROM (
    SELECT program, count(*) AS n FROM student_m_low WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_m_other WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_l_low WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_l_other WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_f_low WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_f_other WHERE status = 'Active' GROUP BY program
) AS partials
GROUP BY program
ORDER BY program;

SELECT program, sum(n)::bigint AS active_students
FROM (
    SELECT program, count(*) AS n FROM student_m_low WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_m_other WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_l_low WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_l_other WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_f_low WHERE status = 'Active' GROUP BY program
    UNION ALL
    SELECT program, count(*) AS n FROM student_f_other WHERE status = 'Active' GROUP BY program
) AS partials
GROUP BY program
ORDER BY program;
