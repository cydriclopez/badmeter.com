
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
