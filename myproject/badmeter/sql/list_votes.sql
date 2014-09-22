
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
