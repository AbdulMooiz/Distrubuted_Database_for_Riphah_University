\set ON_ERROR_STOP on
CREATE OR REPLACE PROCEDURE transfer_student(p_sid integer, p_new_campus char(1))
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_campus char(1);
    v_cgpa numeric(3,2);
    v_tier text;
    v_source_student text;
    v_target_student text;
    v_source_enroll text;
    v_target_enroll text;
    v_student_rows integer;
    v_enroll_rows integer;
BEGIN
    IF p_new_campus NOT IN ('M', 'L', 'F') THEN
        RAISE EXCEPTION 'Campus must be M, L, or F';
    END IF;

    SELECT campus, cgpa INTO v_old_campus, v_cgpa
    FROM student WHERE sid = p_sid;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student % does not exist', p_sid;
    END IF;

    IF v_old_campus = p_new_campus THEN
        RAISE NOTICE 'Student % is already at campus %', p_sid, p_new_campus;
        RETURN;
    END IF;

    v_tier := CASE WHEN v_cgpa < 2.00 THEN 'low' ELSE 'other' END;
    v_source_student := 'student_' || lower(v_old_campus::text) || '_' || v_tier;
    v_target_student := 'student_' || lower(p_new_campus::text) || '_' || v_tier;
    v_source_enroll := 'enroll_' || lower(v_old_campus::text);
    v_target_enroll := 'enroll_' || lower(p_new_campus::text);

    -- Insert at the destination before deleting the source. The surrounding SQL
    -- transaction rolls back all participating operations if a statement fails.
    EXECUTE format(
        'INSERT INTO %I (sid, name, program, campus, cgpa, status) '
        'SELECT sid, name, program, $2, cgpa, status FROM %I WHERE sid = $1',
        v_target_student, v_source_student
    ) USING p_sid, p_new_campus;
    GET DIAGNOSTICS v_student_rows = ROW_COUNT;
    IF v_student_rows <> 1 THEN
        RAISE EXCEPTION 'Expected to move one student row, moved %', v_student_rows;
    END IF;

    EXECUTE format(
        'INSERT INTO %I (sid, cid, semester, grade) '
        'SELECT sid, cid, semester, grade FROM %I WHERE sid = $1',
        v_target_enroll, v_source_enroll
    ) USING p_sid;
    GET DIAGNOSTICS v_enroll_rows = ROW_COUNT;

    EXECUTE format('DELETE FROM %I WHERE sid = $1', v_source_enroll) USING p_sid;
    EXECUTE format('DELETE FROM %I WHERE sid = $1', v_source_student) USING p_sid;

    RAISE NOTICE 'Transferred student % from % to %, and moved % enrollment rows',
        p_sid, v_old_campus, p_new_campus, v_enroll_rows;
END;
$$;
