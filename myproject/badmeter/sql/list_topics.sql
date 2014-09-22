
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
