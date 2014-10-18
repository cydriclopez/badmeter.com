
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
