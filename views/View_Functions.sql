CREATE OR REPLACE VIEW View_Functions AS
SELECT
    p.oid AS FunctionID,
    n.nspname as Schema,
    p.proname as Name,
    pg_catalog.pg_get_function_result(p.oid) AS ResultDataType,
    pg_catalog.pg_get_function_arguments(p.oid) AS ArgumentDataTypes,
    CASE
        WHEN p.proisagg THEN 'agg'
        WHEN p.proiswindow THEN 'window'
        WHEN p.prorettype = 'pg_catalog.trigger'::pg_catalog.regtype THEN 'trigger'
        ELSE 'normal'
    END AS Type,
    CASE
        WHEN p.provolatile = 'i' THEN 'IMMUTABLE'
        WHEN p.provolatile = 's' THEN 'STABLE'
        WHEN p.provolatile = 'v' THEN 'VOLATILE'
    END AS Volatility,
    pg_catalog.pg_get_userbyid(p.proowner) AS Owner,
    l.lanname AS Language,
    p.prosrc AS Sourcecode
FROM pg_catalog.pg_proc p
LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
LEFT JOIN pg_catalog.pg_language l ON l.oid = p.prolang
WHERE pg_catalog.pg_function_is_visible(p.oid)
AND n.nspname <> 'pg_catalog'
AND n.nspname <> 'information_schema'
ORDER BY 1;
