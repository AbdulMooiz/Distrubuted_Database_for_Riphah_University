\set ON_ERROR_STOP on
\echo 'Creating deterministic synthetic Riphah data and distributing fragments...'

-- Ensure the trigger function exists and is properly defined as a trigger function

CREATE OR REPLACE FUNCTION public.sync_faculty_public_replicas()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    -- Delete the old record from both replicas.
    IF TG_OP = 'DELETE' THEN
        DELETE FROM public.faculty_public_lahore
        WHERE fid = OLD.fid;

        DELETE FROM public.faculty_public_faisalabad
        WHERE fid = OLD.fid;

        RETURN OLD;
    END IF;

    -- Handle a change to the faculty ID.
    IF TG_OP = 'UPDATE' AND OLD.fid IS DISTINCT FROM NEW.fid THEN
        DELETE FROM public.faculty_public_lahore
        WHERE fid = OLD.fid;

        DELETE FROM public.faculty_public_faisalabad
        WHERE fid = OLD.fid;
    END IF;

    -- Synchronize the Lahore replica.
    UPDATE public.faculty_public_lahore
    SET name = NEW.name,
        dept = NEW.dept,
        campus = NEW.campus,
        phone = NEW.phone,
        email = NEW.email
    WHERE fid = NEW.fid;

    IF NOT FOUND THEN
        INSERT INTO public.faculty_public_lahore
            (fid, name, dept, campus, phone, email)
        VALUES
            (NEW.fid, NEW.name, NEW.dept, NEW.campus, NEW.phone, NEW.email);
    END IF;

    -- Synchronize the Faisalabad replica.
    UPDATE public.faculty_public_faisalabad
    SET name = NEW.name,
        dept = NEW.dept,
        campus = NEW.campus,
        phone = NEW.phone,
        email = NEW.email
    WHERE fid = NEW.fid;

    IF NOT FOUND THEN
        INSERT INTO public.faculty_public_faisalabad
            (fid, name, dept, campus, phone, email)
        VALUES
            (NEW.fid, NEW.name, NEW.dept, NEW.campus, NEW.phone, NEW.email);
    END IF;

    RETURN NEW;
END;
$function$;


-- Safely drop the trigger if it exists before bulk loading
DROP TRIGGER IF EXISTS faculty_public_replicate ON faculty_public;

BEGIN;

-- Empty all physical fragments, including remote fragments exposed through FDW.
DELETE FROM enroll_m;
DELETE FROM enroll_l;
DELETE FROM enroll_f;
DELETE FROM student_m_low;
DELETE FROM student_m_other;
DELETE FROM student_l_low;
DELETE FROM student_l_other;
DELETE FROM student_f_low;
DELETE FROM student_f_other;
DELETE FROM course_m;
DELETE FROM course_l;
DELETE FROM course_f;
DELETE FROM faculty_public_lahore;
DELETE FROM faculty_public_faisalabad;
DELETE FROM faculty_payroll;
DELETE FROM faculty_public;

CREATE TEMP TABLE seed_student ON COMMIT DROP AS
SELECT sid,
       'Student ' || lpad(sid::text, 5, '0') AS name,
       CASE mod(sid, 4)
           WHEN 0 THEN 'BSCS'
           WHEN 1 THEN 'BSSE'
           WHEN 2 THEN 'BSEE'
           ELSE 'BBA'
       END AS program,
       CASE WHEN sid <= 15000 THEN 'M'
            WHEN sid <= 24000 THEN 'L'
            ELSE 'F' END::char(1) AS campus,
       CASE WHEN mod(sid, 20) = 0
            THEN (1.00 + mod(sid, 100)::numeric / 100)::numeric(3,2)
            ELSE (2.00 + mod(sid * 13, 201)::numeric / 100)::numeric(3,2)
       END AS cgpa,
       CASE WHEN mod(sid, 40) = 0 THEN 'Graduated'
            WHEN mod(sid, 40) = 1 THEN 'Suspended'
            ELSE 'Active' END AS status
FROM generate_series(1, 30000) AS g(sid);

CREATE TEMP TABLE seed_course ON COMMIT DROP AS
SELECT cid,
       CASE WHEN cid <= 450 THEN 'M'
            WHEN cid <= 720 THEN 'L'
            ELSE 'F' END || ' Course ' || lpad(cid::text, 4, '0') AS title,
       3 + mod(cid, 2) AS credits,
       CASE mod(cid, 4)
           WHEN 0 THEN 'Computer Science'
           WHEN 1 THEN 'Software Engineering'
           WHEN 2 THEN 'Electrical Engineering'
           ELSE 'Management Sciences'
       END AS dept,
       CASE WHEN cid <= 450 THEN 'M'
            WHEN cid <= 720 THEN 'L'
            ELSE 'F' END::char(1) AS campus
FROM generate_series(1, 900) AS g(cid);

-- 8 enrollments per student = 240,000 rows with 5% cross-campus distribution.
CREATE TEMP TABLE seed_enroll ON COMMIT DROP AS
SELECT s.sid,
       CASE
         WHEN ((s.sid - 1) * 8 + (x.seq - 1)) % 20 = 0 THEN
           CASE s.campus
             WHEN 'M' THEN CASE WHEN mod(s.sid + x.seq, 2) = 0
                                THEN 451 + mod(s.sid * 17 + x.seq * 29, 270)
                                ELSE 721 + mod((s.sid + x.seq) / 2, 180) END
             WHEN 'L' THEN CASE WHEN mod(s.sid + x.seq, 2) = 0
                                THEN 721 + mod((s.sid + x.seq) / 2, 180)
                                ELSE 1 + mod(s.sid * 17 + x.seq * 29, 450) END
             ELSE CASE WHEN mod(s.sid + x.seq, 2) = 0
                       THEN 1 + mod(s.sid * 17 + x.seq * 29, 450)
                       ELSE 451 + mod(s.sid * 17 + x.seq * 29, 270) END
           END
         ELSE
           CASE s.campus
             WHEN 'M' THEN 1 + mod(s.sid * 17 + x.seq * 29, 450)
             WHEN 'L' THEN 451 + mod(s.sid * 17 + x.seq * 29, 270)
             ELSE 721 + mod(s.sid * 17 + x.seq * 29, 180)
           END
       END AS cid,
       CASE WHEN x.seq <= 2 THEN 'Fall 2024'
            WHEN x.seq <= 4 THEN 'Spring 2025'
            WHEN x.seq <= 6 THEN 'Fall 2025'
            ELSE 'Spring 2026' END AS semester,
       CASE WHEN x.seq >= 7 THEN NULL
            WHEN mod(s.sid + x.seq, 5) = 0 THEN 'A'
            WHEN mod(s.sid + x.seq, 5) = 1 THEN 'B+'
            WHEN mod(s.sid + x.seq, 5) = 2 THEN 'B'
            WHEN mod(s.sid + x.seq, 5) = 3 THEN 'C+'
            ELSE 'C' END AS grade
FROM seed_student s
CROSS JOIN generate_series(1, 8) AS x(seq);

-- STUDENT minterm fragments
INSERT INTO student_m_low  SELECT * FROM seed_student WHERE campus = 'M' AND cgpa < 2.00;
INSERT INTO student_m_other SELECT * FROM seed_student WHERE campus = 'M' AND cgpa >= 2.00;
INSERT INTO student_l_low  SELECT * FROM seed_student WHERE campus = 'L' AND cgpa < 2.00;
INSERT INTO student_l_other SELECT * FROM seed_student WHERE campus = 'L' AND cgpa >= 2.00;
INSERT INTO student_f_low  SELECT * FROM seed_student WHERE campus = 'F' AND cgpa < 2.00;
INSERT INTO student_f_other SELECT * FROM seed_student WHERE campus = 'F' AND cgpa >= 2.00;

-- COURSE horizontal fragments
INSERT INTO course_m SELECT * FROM seed_course WHERE campus = 'M';
INSERT INTO course_l SELECT * FROM seed_course WHERE campus = 'L';
INSERT INTO course_f SELECT * FROM seed_course WHERE campus = 'F';

-- ENROLL derived fragments
INSERT INTO enroll_m SELECT e.* FROM seed_enroll e JOIN seed_student s USING (sid) WHERE s.campus = 'M';
INSERT INTO enroll_l SELECT e.* FROM seed_enroll e JOIN seed_student s USING (sid) WHERE s.campus = 'L';
INSERT INTO enroll_f SELECT e.* FROM seed_enroll e JOIN seed_student s USING (sid) WHERE s.campus = 'F';

-- FACULTY data
INSERT INTO faculty_public (fid, name, dept, campus, phone, email)
SELECT fid,
       'Faculty ' || lpad(fid::text, 4, '0'),
       CASE mod(fid, 4)
           WHEN 0 THEN 'Computer Science'
           WHEN 1 THEN 'Software Engineering'
           WHEN 2 THEN 'Electrical Engineering'
           ELSE 'Management Sciences'
       END,
       CASE WHEN fid <= 600 THEN 'M'
            WHEN fid <= 960 THEN 'L'
            ELSE 'F' END::char(1),
       '+92 51 ' || lpad((1000000 + fid)::text, 7, '0'),
       'faculty' || fid || '@riphah.example'
FROM generate_series(1, 1200) AS g(fid);

INSERT INTO faculty_public_lahore SELECT * FROM faculty_public;
INSERT INTO faculty_public_faisalabad SELECT * FROM faculty_public;

INSERT INTO faculty_payroll (fid, salary, bank_account)
SELECT fid,
       (60000 + mod(fid, 20) * 1250)::numeric(12,2),
       'PK' || lpad((fid::bigint * 9876543)::text, 16, '0')
FROM generate_series(1, 1200) AS g(fid);

COMMIT;

-- Re-create trigger safely after bulk loading inside the transaction boundary
CREATE TRIGGER faculty_public_replicate
AFTER INSERT OR UPDATE OR DELETE ON faculty_public
FOR EACH ROW EXECUTE FUNCTION public.sync_faculty_public_replicas();

ANALYZE student_m_low;
ANALYZE student_m_other;
ANALYZE course_m;
ANALYZE enroll_m;
ANALYZE faculty_public;
ANALYZE faculty_payroll;

\echo 'Seed complete.'
