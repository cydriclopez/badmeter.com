
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

    t_now := get_timestamp(p_now);
    IF t_now IS NULL THEN
        t_now := now();
    END IF;

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
