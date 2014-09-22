
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
