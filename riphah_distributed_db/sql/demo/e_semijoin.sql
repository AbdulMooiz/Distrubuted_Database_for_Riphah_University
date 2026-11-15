\set ON_ERROR_STOP on
\echo '=== Semijoin versus full join at Faisalabad ==='
\echo 'R = ENROLL_F (local), S = COURSE_M (stored at Main). The key is CID.'

WITH s AS (
    SELECT count(*)::numeric AS s_rows,
           avg(pg_column_size(c))::numeric AS tuple_bytes
    FROM course_m c
),
r AS (
    SELECT count(DISTINCT cid)::numeric AS keys
    FROM enroll_f
    WHERE semester = 'Spring 2026' AND cid BETWEEN 1 AND 450
),
m AS (
    SELECT count(*)::numeric AS matching_rows
    FROM course_m c
    WHERE c.cid IN (
        SELECT DISTINCT cid FROM enroll_f
        WHERE semester = 'Spring 2026' AND cid BETWEEN 1 AND 450
    )
)
SELECT s.s_rows AS full_course_rows,
       round(s.tuple_bytes, 1) AS average_course_tuple_bytes,
       r.keys AS distinct_cids_sent_to_main,
       m.matching_rows AS matching_course_rows_returned,
       round(s.s_rows * s.tuple_bytes)::bigint AS full_join_bytes,
       round(r.keys * 4 + m.matching_rows * s.tuple_bytes)::bigint AS semijoin_bytes,
       round(100 * (1 - (r.keys * 4 / NULLIF(s.s_rows * s.tuple_bytes, 0))), 1) AS break_even_match_percent,
       CASE WHEN r.keys * 4 + m.matching_rows * s.tuple_bytes < s.s_rows * s.tuple_bytes
            THEN 'semijoin wins on estimated bytes' ELSE 'full join wins on estimated bytes' END AS verdict
FROM s CROSS JOIN r CROSS JOIN m;

\echo
\echo 'Hypothetical values: semijoin bytes = keys*4 + matching_rows*tuple_width.'
WITH scenarios(case_name, s_rows, tuple_bytes, keys, match_fraction) AS (
    VALUES
      ('Wide tuples, few keys, selective', 450::numeric, 200::numeric, 60::numeric, 0.13::numeric),
      ('Wide tuples, many keys, half match', 450, 200, 300, 0.50),
      ('Wide tuples, almost all match', 450, 200, 400, 0.99),
      ('Narrow tuples, few keys', 450, 8, 60, 0.13),
      ('Narrow tuples, many keys, most match', 450, 8, 450, 0.80),
      ('Tuple width equals key width', 450, 4, 400, 0.40)
), costs AS (
    SELECT *,
           s_rows * tuple_bytes AS full_bytes,
           keys * 4 + round(s_rows * match_fraction) * tuple_bytes AS semi_bytes,
           100 * (1 - (keys * 4 / (s_rows * tuple_bytes))) AS break_even_percent
    FROM scenarios
)
SELECT case_name, s_rows, tuple_bytes, keys,
       round(100 * match_fraction, 1) AS match_percent,
       full_bytes::bigint AS full_join_bytes,
       semi_bytes::bigint AS semijoin_bytes,
       round(break_even_percent, 1) AS break_even_match_percent,
       CASE WHEN semi_bytes < full_bytes THEN 'semijoin wins' ELSE 'full join wins' END AS result
FROM costs;

\echo
\echo 'Semijoin wins when match_percent is below break_even_match_percent.'
\echo 'These byte estimates exclude the extra round trip, latency, and protocol overhead.';
