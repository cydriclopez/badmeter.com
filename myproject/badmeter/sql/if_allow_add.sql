
-- Used to enforce one vote per day rule.
CREATE OR REPLACE FUNCTION if_allow_add(
    p_badmeter_topic_id int,
    p_badmeter_cookie_id int
)
RETURNS boolean
AS $$
BEGIN
    RETURN if_allow_add(
        p_badmeter_topic_id,
        p_badmeter_cookie_id,
        now()::text
    );
END;
$$ LANGUAGE plpgsql;


/*
    Overload if_allow_add function and add 'p_now' parameter.
    This is for testing purposes so we can feed it a custom date for testing.
*/
CREATE OR REPLACE FUNCTION if_allow_add(
    p_badmeter_topic_id int,
    p_badmeter_cookie_id int,
    p_now text
)
RETURNS boolean
AS $$
DECLARE
    t_now timestamp;
    t_now_start timestamp;
    t_now_end timestamp;
    t_badmeter_vote_count int;
BEGIN
    SELECT COALESCE(get_timestamp(p_now), now())
        INTO t_now;

    t_now_start := date_trunc('day', t_now);
    t_now_end := t_now_start + interval '1 day';

    SELECT count(*)
        INTO t_badmeter_vote_count
        FROM badmeter_vote
        WHERE topic_id = p_badmeter_topic_id
            AND cookie_id = p_badmeter_cookie_id
            AND date_created >= t_now_start
            AND date_created < t_now_end;

    RETURN (t_badmeter_vote_count = 0);
END;
$$ LANGUAGE plpgsql;
