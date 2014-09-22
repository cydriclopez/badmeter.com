
-- Get purge date the date when number of votes fall below the quota.
CREATE OR REPLACE FUNCTION get_purgedate(
    p_topic_slug text,
    OUT purge_date text,
    OUT vote_needed text)
AS $$
BEGIN
    SELECT *
        INTO purge_date, vote_needed
        FROM get_purgedate(
            p_topic_slug,
            now()::text);
END;
$$ LANGUAGE plpgsql;


-- Overload function get_purgedate adding a timestamp parameter.
CREATE OR REPLACE FUNCTION get_purgedate(
    p_topic_slug text,
    p_now text,
    OUT purge_date text,
    OUT vote_needed text)
AS $$
DECLARE
    t_now timestamp;
    t_badmeter_topic_id integer;
    t_start timestamp;
    t_end timestamp;
    t_count int;
    t_oneday interval := interval '1 day';
    t_interval interval;
    t_quota int;
BEGIN
    -- Get application configuration from central location
    -- in get_configuration().
    SELECT interval_days, vote_quota
        INTO t_interval, t_quota
        FROM get_configuration();

    t_now := get_timestamp(p_now);
    IF t_now IS NULL THEN
        t_now := now();
    END IF;

    -- First get the date the topic was created.
    SELECT id, date_created
        INTO t_badmeter_topic_id, t_start
        FROM badmeter_topic
        WHERE topic_slug = p_topic_slug;

    t_start := date_trunc('day', t_start);

    -- End date is interval_days from start date;
    t_end := t_start + t_interval;

    -- If topic made it beyond first interval_days period tweak start & end dates.
    IF t_end < t_now THEN
        t_end := date_trunc('day', t_now);
        t_start := t_end - t_interval;
    END IF;

    LOOP
        RAISE NOTICE 't_start=%',t_start;
        RAISE NOTICE 't_end=%',t_end;

        -- Count the number of votes during the interval_days period.
        SELECT count(*)
            INTO t_count
            FROM badmeter_vote
            WHERE date_created >= t_start
                AND date_created <= t_end
                AND counted IS TRUE
                AND topic_id = t_badmeter_topic_id;

        RAISE NOTICE 't_count=%',t_count;

        -- If there are not enough votes exit & return the end date.
        EXIT WHEN (t_count < t_quota);

        -- Try again on the next interval_days period.
        t_end := t_end + t_oneday;
        t_start := t_end - t_interval;
    END LOOP;

    purge_date := to_char(t_end, 'FMMon. DD, YYYY');
    vote_needed := (t_quota - t_count)::text;
END;
$$ LANGUAGE plpgsql;
