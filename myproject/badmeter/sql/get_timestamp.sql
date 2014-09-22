
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
