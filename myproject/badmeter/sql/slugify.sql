
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
