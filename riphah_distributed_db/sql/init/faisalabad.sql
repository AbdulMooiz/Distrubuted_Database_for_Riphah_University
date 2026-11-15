-- Initial schema for Faisalabad campus (F).
-- This file is run automatically when the PostgreSQL volume is first created.
CREATE EXTENSION IF NOT EXISTS postgres_fdw;


CREATE TABLE student_f_low (
    sid       integer PRIMARY KEY,
    name      text NOT NULL,
    program   text NOT NULL,
    campus    char(1) NOT NULL CHECK (campus = 'F'),
    cgpa      numeric(3,2) NOT NULL CHECK (cgpa < 2.00),
    status    text NOT NULL CHECK (status IN ('Active', 'Graduated', 'Suspended'))
);
CREATE INDEX student_f_low_program_idx
    ON student_f_low (program);

CREATE TABLE student_f_other (
    sid       integer PRIMARY KEY,
    name      text NOT NULL,
    program   text NOT NULL,
    campus    char(1) NOT NULL CHECK (campus = 'F'),
    cgpa      numeric(3,2) NOT NULL CHECK (cgpa >= 2.00),
    status    text NOT NULL CHECK (status IN ('Active', 'Graduated', 'Suspended'))
);
CREATE INDEX student_f_other_program_idx
    ON student_f_other (program);

CREATE TABLE course_f (
    cid      integer PRIMARY KEY,
    title    text NOT NULL,
    credits  integer NOT NULL,
    dept     text NOT NULL,
    campus   char(1) NOT NULL CHECK (campus = 'F')
);

CREATE TABLE enroll_f (
    sid       integer NOT NULL,
    cid       integer NOT NULL,
    semester  text NOT NULL,
    grade     text,
    PRIMARY KEY (sid, cid, semester)
);
CREATE INDEX enroll_f_cid_idx ON enroll_f (cid);
CREATE INDEX enroll_f_sid_idx ON enroll_f (sid);

CREATE TABLE faculty_public (
    fid     integer PRIMARY KEY,
    name    text NOT NULL,
    dept    text NOT NULL,
    campus  char(1) NOT NULL CHECK (campus IN ('M','L','F')),
    phone   text,
    email   text NOT NULL
);

CREATE ROLE directory_reader NOLOGIN;
GRANT SELECT ON faculty_public TO directory_reader;

CREATE SERVER srv_m
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'main', port '5432', dbname 'riphah');
CREATE USER MAPPING FOR postgres SERVER srv_m
    OPTIONS (user 'postgres', password 'postgres');

CREATE FOREIGN TABLE student_m_low (
    sid integer, name text, program text, campus char(1), cgpa numeric(3,2), status text
) SERVER srv_m OPTIONS (schema_name 'public', table_name 'student_m_low');

CREATE FOREIGN TABLE student_m_other (
    sid integer, name text, program text, campus char(1), cgpa numeric(3,2), status text
) SERVER srv_m OPTIONS (schema_name 'public', table_name 'student_m_other');

CREATE FOREIGN TABLE course_m (
    cid integer, title text, credits integer, dept text, campus char(1)
) SERVER srv_m OPTIONS (schema_name 'public', table_name 'course_m');

CREATE FOREIGN TABLE enroll_m (
    sid integer, cid integer, semester text, grade text
) SERVER srv_m OPTIONS (schema_name 'public', table_name 'enroll_m');

CREATE FOREIGN TABLE faculty_public_main (
    fid integer, name text, dept text, campus char(1), phone text, email text
) SERVER srv_m OPTIONS (schema_name 'public', table_name 'faculty_public');

CREATE SERVER srv_l
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'lahore', port '5432', dbname 'riphah');
CREATE USER MAPPING FOR postgres SERVER srv_l
    OPTIONS (user 'postgres', password 'postgres');

CREATE FOREIGN TABLE student_l_low (
    sid integer, name text, program text, campus char(1), cgpa numeric(3,2), status text
) SERVER srv_l OPTIONS (schema_name 'public', table_name 'student_l_low');

CREATE FOREIGN TABLE student_l_other (
    sid integer, name text, program text, campus char(1), cgpa numeric(3,2), status text
) SERVER srv_l OPTIONS (schema_name 'public', table_name 'student_l_other');

CREATE FOREIGN TABLE course_l (
    cid integer, title text, credits integer, dept text, campus char(1)
) SERVER srv_l OPTIONS (schema_name 'public', table_name 'course_l');

CREATE FOREIGN TABLE enroll_l (
    sid integer, cid integer, semester text, grade text
) SERVER srv_l OPTIONS (schema_name 'public', table_name 'enroll_l');

CREATE FOREIGN TABLE faculty_public_lahore (
    fid integer, name text, dept text, campus char(1), phone text, email text
) SERVER srv_l OPTIONS (schema_name 'public', table_name 'faculty_public');

CREATE OR REPLACE VIEW student AS
SELECT sid, name, program, campus, cgpa, status FROM student_m_low WHERE campus = 'M' AND cgpa < 2.00
UNION ALL
SELECT sid, name, program, campus, cgpa, status FROM student_m_other WHERE campus = 'M' AND cgpa >= 2.00
UNION ALL
SELECT sid, name, program, campus, cgpa, status FROM student_l_low WHERE campus = 'L' AND cgpa < 2.00
UNION ALL
SELECT sid, name, program, campus, cgpa, status FROM student_l_other WHERE campus = 'L' AND cgpa >= 2.00
UNION ALL
SELECT sid, name, program, campus, cgpa, status FROM student_f_low WHERE campus = 'F' AND cgpa < 2.00
UNION ALL
SELECT sid, name, program, campus, cgpa, status FROM student_f_other WHERE campus = 'F' AND cgpa >= 2.00;

CREATE OR REPLACE VIEW course AS
SELECT cid, title, credits, dept, campus FROM course_m WHERE campus = 'M'
UNION ALL
SELECT cid, title, credits, dept, campus FROM course_l WHERE campus = 'L'
UNION ALL
SELECT cid, title, credits, dept, campus FROM course_f WHERE campus = 'F';

CREATE OR REPLACE VIEW enroll AS
SELECT sid, cid, semester, grade FROM enroll_m
UNION ALL
SELECT sid, cid, semester, grade FROM enroll_l
UNION ALL
SELECT sid, cid, semester, grade FROM enroll_f;

CREATE OR REPLACE VIEW faculty_directory AS
SELECT fid, name, dept, email FROM faculty_public;
GRANT SELECT ON faculty_directory TO directory_reader;

CREATE OR REPLACE VIEW class_roster AS
SELECT e.cid, e.sid, s.name, s.program, s.campus AS student_campus,
       e.semester, e.grade
FROM enroll e
JOIN student s ON s.sid = e.sid;
