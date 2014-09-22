
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
