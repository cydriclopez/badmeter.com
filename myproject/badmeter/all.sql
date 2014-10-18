
CREATE OR REPLACE FUNCTION add_topic(
    p_topic_title text,
    p_topic_slug text,      -- Will use Django's slugify() function.
    p_cookie_string text,
    OUT return_id int,
    OUT status_message text)
AS $$
BEGIN
    SELECT * INTO return_id, status_message
        FROM add_topic(
            p_topic_title,
            p_topic_slug,
            p_cookie_string,
            now()::text);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION add_topic(
    p_topic_title text,
    p_topic_slug text,
    p_cookie_string text,
    p_now text,
    OUT return_id int,
    OUT status_message text)
AS $$
DECLARE
    t_now timestamp;
    t_badmeter_cookie_id int;
    t_badmeter_topic_id int;
BEGIN
    SELECT COALESCE(get_timestamp(p_now), now())
        INTO t_now;

    SELECT id
        INTO t_badmeter_topic_id
        FROM badmeter_topic
        WHERE topic_slug = p_topic_slug;

    -- Add topic if new. Note cookie_id initially NULL.
    IF t_badmeter_topic_id IS NULL THEN
        INSERT INTO badmeter_topic (
                topic_title, topic_slug, badmeter, votes_positive,
                votes_negative, cookie_id, date_created, date_updated)
            VALUES (
                p_topic_title, p_topic_slug, 50, 0,
                0, NULL, t_now, t_now)
            -- Return newly inserted topic record id.
            RETURNING badmeter_topic.id INTO t_badmeter_topic_id;

        return_id := t_badmeter_topic_id;
        status_message := 'badmeter_topic.id';
    ELSE
        -- Already existing topic no record inserted.
        return_id := -1;
        status_message := 'Already existing topic no record inserted.';
    END IF;

    -- Check if cookie exists. Note that badmeter_cookie stores counters on
    -- a per cookie_string AND topic_id basis.
    SELECT id
        INTO t_badmeter_cookie_id
        FROM badmeter_cookie
        WHERE cookie_string = p_cookie_string
            AND topic_id = t_badmeter_topic_id;

    -- Create the badmeter_cookie record if not existing.
    IF t_badmeter_cookie_id IS NULL THEN
        INSERT INTO badmeter_cookie (
                cookie_string, votes_positive, votes_negative, date_created, date_updated, topic_id)
            VALUES (
                p_cookie_string, 0, 0, t_now, t_now, t_badmeter_topic_id)
            -- Grab newly inserted cookie record id.
            RETURNING badmeter_cookie.id INTO t_badmeter_cookie_id;
    END IF;

    -- Now go back to the badmeter_topic table just inserted above and
    -- update the cookie_id. Keep record of which cookie created
    -- this topic. Note that badmeter_topic & badmeter_cookie have cyclic
    -- foreigh-key dependencies.
    UPDATE badmeter_topic
        SET cookie_id = t_badmeter_cookie_id
        WHERE id = t_badmeter_topic_id
            AND cookie_id IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to add votes in badmeter_vote.
-- First 2 votes are marked not counted.
-- The 3rd vote counts including previous 1st & 2nd votes.
CREATE OR REPLACE FUNCTION add_vote(
    p_topic_slug text,
    p_cookie_string text,
    p_comment text,
    p_vote text,
    OUT return_id int,
    OUT status_message text)
AS $$
BEGIN
    SELECT *
        INTO return_id, status_message
        FROM add_vote(
            p_topic_slug,
            p_cookie_string,
            p_comment,
            p_vote,
            now()::text);
END;
$$ LANGUAGE plpgsql;


/*
    Overload add_vote function and add 'p_now' parameter.
    This is for testing purposes so we can feed it a custom date for testing.
*/
CREATE OR REPLACE FUNCTION add_vote(
    p_topic_slug text,
    p_cookie_string text,
    p_comment text,
    p_vote text,
    p_now text,
    OUT return_id int,
    OUT status_message text)
AS $$
DECLARE
    t_badmeter_cookie_id int;
    t_badmeter_topic_id int;
    t_now timestamp;

    t_positive int;
    t_negative int;

    t_positive_sum int;
    t_negative_sum int;

    t_diff int;
    t_sum int;
    t_badmeter int;

    t_vote boolean := p_vote::boolean;
    t_badmeter_vote_count int;
BEGIN
    -- Check if topic exists.
    SELECT id
        INTO t_badmeter_topic_id
        FROM badmeter_topic
        WHERE topic_slug = p_topic_slug;

    IF t_badmeter_topic_id IS NULL THEN
        -- Makes no sense to continue with a topic that does not exist.
        return_id := -1;
        status_message := 'Error: You Cannot vote on non-existing topic.';
        RETURN;
    END IF;

    SELECT COALESCE(get_timestamp(p_now), now())
        INTO t_now;

    -- Check if cookie exists.
    SELECT id
        INTO t_badmeter_cookie_id
        FROM badmeter_cookie
        WHERE cookie_string = p_cookie_string
            AND topic_id = t_badmeter_topic_id;

    -- RAISE NOTICE 't_badmeter_cookie_id = %', t_badmeter_cookie_id;

    -- Add to badmeter_cookie if cookie is new.
    IF t_badmeter_cookie_id IS NULL THEN
        INSERT INTO badmeter_cookie (
                cookie_string, votes_positive, votes_negative, date_created, date_updated, topic_id)
            VALUES (
                p_cookie_string, 0, 0, t_now, t_now, t_badmeter_topic_id)
            -- Grab newly inserted cookie record id.
            RETURNING badmeter_cookie.id INTO t_badmeter_cookie_id;
    END IF;

    -- Enforce one vote per day rule.
    IF if_allow_add(t_badmeter_topic_id, t_badmeter_cookie_id, t_now::text) THEN
        INSERT INTO badmeter_vote (
                topic_id, cookie_id, comment, vote, date_created)
            VALUES (
                t_badmeter_topic_id, t_badmeter_cookie_id, p_comment, t_vote, t_now)
            RETURNING badmeter_vote.id, 'badmeter_vote.id'::text
                -- return_id should be >= 0 for normal save.
                INTO return_id, status_message;

        -- Count the total number of votes per this topic.
        SELECT count(*)
            INTO t_badmeter_vote_count
            FROM badmeter_vote
            WHERE topic_id = t_badmeter_topic_id
                AND cookie_id = t_badmeter_cookie_id;

        -- On the 3rd or more vote set counted = TRUE.
        IF t_badmeter_vote_count = 3 THEN
            UPDATE badmeter_vote SET counted = TRUE
                WHERE topic_id = t_badmeter_topic_id
                    AND cookie_id = t_badmeter_cookie_id;

            SELECT count(*)
                INTO t_positive_sum
                FROM badmeter_vote
                WHERE topic_id = t_badmeter_topic_id
                    AND cookie_id = t_badmeter_cookie_id
                    AND vote IS TRUE
                    AND counted IS TRUE;

            SELECT count(*)
                INTO t_negative_sum
                FROM badmeter_vote
                WHERE topic_id = t_badmeter_topic_id
                    AND cookie_id = t_badmeter_cookie_id
                    AND vote IS NOT TRUE
                    AND counted IS TRUE;

            -- Update badmeter_topic & badmeter_cookie accordingly.
            UPDATE badmeter_cookie
                SET votes_positive = t_positive_sum,
                    votes_negative = t_negative_sum
                WHERE id = t_badmeter_cookie_id
                    AND topic_id = t_badmeter_topic_id;

            UPDATE badmeter_topic
                SET votes_positive = (votes_positive + t_positive_sum),
                    votes_negative = (votes_negative + t_negative_sum)
                WHERE id = t_badmeter_topic_id
                RETURNING votes_positive, votes_negative
                    INTO t_positive, t_negative;

        ELSIF t_badmeter_vote_count > 3 THEN
            UPDATE badmeter_vote SET counted = TRUE
                WHERE id = return_id;

            -- Update badmeter_topic & badmeter_cookie accordingly.
            IF t_vote IS TRUE THEN
                UPDATE badmeter_topic
                    SET votes_positive = (votes_positive + 1)
                    WHERE id = t_badmeter_topic_id
                    RETURNING votes_positive, votes_negative
                        INTO t_positive, t_negative;

                UPDATE badmeter_cookie
                    SET votes_positive = (votes_positive + 1)
                    WHERE id = t_badmeter_cookie_id
                        AND topic_id = t_badmeter_topic_id;
            ELSE
                UPDATE badmeter_topic
                    SET votes_negative = (votes_negative + 1)
                    WHERE id = t_badmeter_topic_id
                    RETURNING votes_positive, votes_negative
                        INTO t_positive, t_negative;

                UPDATE badmeter_cookie
                    SET votes_negative = (votes_negative + 1)
                    WHERE id = t_badmeter_cookie_id
                        AND topic_id = t_badmeter_topic_id;
            END IF;
        END IF;

        IF t_badmeter_vote_count >= 3 THEN
            -- Compute & update badmeter value.
            t_diff := t_positive - t_negative;
            t_sum := t_positive + t_negative;
            -- Prevent divide-by-zero error.
            IF t_sum = 0 THEN
                t_sum := 1;
            END IF;
            t_badmeter := 50 + floor((t_diff / t_sum::float) * 50);

            UPDATE badmeter_topic
                SET badmeter = t_badmeter,
                    date_updated = t_now
                WHERE id = t_badmeter_topic_id;
        END IF;
    ELSE
        return_id := -1;
        status_message := 'You are limited to one vote per day per topic.';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Provides central storage for application configuration.
-- Used by:
--   get_purgedate()
--   purge_scan()
--   badmeter.views.StatsTableMixin.get_context_data()
--   badmeter.views.HomeTemplateView.get_context_data()
CREATE OR REPLACE FUNCTION get_configuration(
    OUT interval_days interval,
    OUT vote_quota int
) AS $$
BEGIN
    SELECT  interval '30 days',
            100
        into
            interval_days,
            vote_quota;
END;
$$ LANGUAGE plpgsql;

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

    SELECT COALESCE(get_timestamp(p_now), now())
        INTO t_now;

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

CREATE OR REPLACE FUNCTION get_status_message(
    p_topic_slug text,
    p_cookie_string text,
    OUT status_message text
) AS $$
DECLARE
    t_badmeter_vote_count int;
    t_badmeter_cookie_id int;
    t_badmeter_topic_id int;
BEGIN
    -- Check if topic exists.
    SELECT id
        INTO t_badmeter_topic_id
        FROM badmeter_topic
        WHERE topic_slug = p_topic_slug;

    -- ~ RAISE NOTICE 't_badmeter_topic_id = %', t_badmeter_topic_id;
    IF t_badmeter_topic_id IS NULL THEN
        status_message := 'Non-existing topic. Enter new topic above in "Search/New Topic".';
        -- Makes no sense to continue with a non-existing topic.
        RETURN;
    END IF;

    -- Check if cookie exists.
    SELECT id
        INTO t_badmeter_cookie_id
        FROM badmeter_cookie
        WHERE cookie_string = p_cookie_string
            AND topic_id = t_badmeter_topic_id;

    IF t_badmeter_cookie_id IS NULL THEN
        -- This cookie could not have voted since it does not exist in badmeter_cookie table.
        t_badmeter_vote_count := 0;
    ELSE
        -- Count the total number of votes per this topic.
        SELECT count(*)
            INTO t_badmeter_vote_count
            FROM badmeter_vote
            WHERE topic_id = t_badmeter_topic_id
                AND cookie_id = t_badmeter_cookie_id;
    END IF;

    IF t_badmeter_vote_count = 0 THEN
        status_message := 'Your cookie is new to this topic. Your vote will count AFTER 3 votes. ';
    ELSIF t_badmeter_vote_count < 3 THEN
        status_message := 'Your votes will count after ' || (3 - t_badmeter_vote_count)::text || ' more vote(s). ';
    END IF;

    -- Enforce one vote per day per topic rule.
    IF if_allow_add(t_badmeter_topic_id, t_badmeter_cookie_id) THEN
        status_message := concat(status_message, 'You can vote today. ');
    ELSE
        status_message := concat(status_message, 'You have already voted today. ');
    END IF;

    status_message := concat(status_message, 'You are limited to one vote per day per topic.');

    -- ~ RAISE NOTICE 'status_message = %', status_message;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_timestamp(
    p_timestamp text
)
RETURNS
    timestamp
AS $$
DECLARE
    t_timestamp timestamp;
BEGIN
    t_timestamp := p_timestamp::timestamp;
    RETURN t_timestamp;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION list_topics(
    p_topic_title text
)
RETURNS TABLE(
    id integer,
    topic_title character varying(100),
    topic_slug character varying(100)
) AS $$
BEGIN
    RETURN QUERY
        SELECT A.id, A.topic_title, A.topic_slug
            FROM badmeter_topic A
            WHERE A.topic_title ILIKE p_topic_title||'%'
            ORDER BY A.topic_title
            LIMIT 25;
END;
$$ LANGUAGE plpgsql;

/*
    'id': obj.id,
    'label': obj.topic_title,
    'value': obj.topic_slug})
*/

CREATE OR REPLACE FUNCTION list_votes(
    p_topic_slug text
)
RETURNS TABLE(
    id text,
    counted text,
    cookie_string text,
    comment text,
    vote text,
    date_created text,
    votes_negative int,
    votes_positive int
) AS $$
BEGIN
    RETURN QUERY
        SELECT A.id::text, A.counted::text,
            C.cookie_string::text, A.comment::text, A.vote::text,
            to_char(A.date_created, 'FMMonth DD, YYYY HH:MI:SS'),
            C.votes_negative, C.votes_positive
        FROM badmeter_vote A, badmeter_topic B, badmeter_cookie C
        WHERE A.topic_id = B.id
            AND A.cookie_id = C.id
            AND B.topic_slug = p_topic_slug
        ORDER BY A.date_created DESC
        LIMIT 100 OFFSET 0;
END;
$$ LANGUAGE plpgsql;

-- Purge a topic given its topic_slug.
CREATE OR REPLACE FUNCTION purge_one(
    p_topic_slug text
)
RETURNS void
AS $$
DECLARE
    t_badmeter_topic_id int;
BEGIN
    SELECT id
        INTO t_badmeter_topic_id
        FROM badmeter_topic
        WHERE topic_slug = p_topic_slug;

    PERFORM purge_one(t_badmeter_topic_id);
END;
$$ LANGUAGE plpgsql;


-- Overload purge_one and purge a topic given its topic_id.
CREATE OR REPLACE FUNCTION purge_one(
    p_badmeter_topic_id int
)
RETURNS void
AS $$
BEGIN
    -- Delete records in badmeter_vote.
    DELETE FROM badmeter_vote
        WHERE topic_id = p_badmeter_topic_id;

    -- Remove badmeter_topic foreignkey dependence on badmeter_cookie.
    -- This is so we can delete records in badmeter_cookie.
    UPDATE badmeter_topic
        SET cookie_id = NULL
        WHERE id = p_badmeter_topic_id;

    -- Delete records in badmeter_cookie.
    DELETE FROM badmeter_cookie
        WHERE topic_id = p_badmeter_topic_id;

    -- Delete records in badmeter_topic.
    DELETE FROM badmeter_topic
        WHERE id = p_badmeter_topic_id;
END;
$$ LANGUAGE plpgsql;

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

    SELECT COALESCE(get_timestamp(p_now), now())
        INTO t_now;

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

CREATE OR REPLACE FUNCTION slugify(
    p_text text
)
RETURNS
    text
AS $$
BEGIN
    RETURN regexp_replace(
        trim(
            regexp_replace(
                lower(p_text), '[^0-9a-z]+', ' ', 'g'
            )
        ), '[ ]+', '-', 'g'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;
