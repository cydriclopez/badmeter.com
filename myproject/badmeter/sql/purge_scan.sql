
CREATE OR REPLACE FUNCTION purge_scan()
RETURNS void
AS $$
BEGIN
    PERFORM purge_scan(now()::text);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION purge_scan(
    p_now text
)
RETURNS void
AS $$
DECLARE
    t_now timestamp;
    t_start timestamp;
    t_end timestamp;
    t_badmeter_topic_id int;
    t_date_created timestamp;
    t_topic_slug text;
    t_badmeter_vote_count int;
    t_interval interval;    -- := interval '11 days';
    t_quota int;            -- := 100;
    -- ~ t_timestamp timestamp;
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

    t_end := date_trunc('day', t_now);
    t_start := t_end - t_interval;

    RAISE NOTICE 'start = %', t_start;
    RAISE NOTICE 'end = %', t_end;

    FOR t_badmeter_topic_id, t_date_created, t_topic_slug IN
        SELECT id, date_created, topic_slug
            FROM badmeter_topic
            ORDER BY id
    LOOP
        IF t_now > (date_trunc('day', t_date_created) + t_interval) THEN

            SELECT count(*)
                INTO t_badmeter_vote_count
                FROM badmeter_vote
                WHERE topic_id = t_badmeter_topic_id
                    AND date_created >= t_start
                    AND date_created < t_end;

            IF t_badmeter_vote_count < t_quota THEN

                -- ~ RAISE NOTICE 'topic_slug = %', t_topic_slug;
                -- ~ RAISE NOTICE 't_badmeter_topic_id = %', t_badmeter_topic_id;
                PERFORM purge_one(t_badmeter_topic_id);

                -- ~ RAISE NOTICE 't_date_created = %', t_date_created;
                -- ~ t_timestamp := date_trunc('day', t_date_created) + t_interval;
                -- ~ RAISE NOTICE 't_purge_date = %', t_timestamp;

            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
