SYNOPSIS

-- 1. Inspect what changes your deployment would cause to the functions:
--    Wrap the SQL your deployment consists of within dollar-quotes and pass it as the first argument to Deploy. The second argument must be NULL.
--    The deployment most typically consists of a single CREATE OR REPLACE FUNCTION statement, replacing the existing source code of an existing function,
--    but it could of course include statements creating new functions, dropping functions, changing ownership, etc.
--    In this step a rollback will be done before the function returns, so the SQL will have no effect, it will only execute it in order to present you with a diff.
SELECT Deploy($DEPLOY$
CREATE OR REPLACE FUNCTION Foo() RETURNS BOOLEAN AS $BODY$
DECLARE
BEGIN
RETURN TRUE;
END;
$BODY$ LANGUAGE plpgsql VOLATILE;
$DEPLOY$, NULL);

-- Example output from Deploy-function:
                      deploy                      
--------------------------------------------------
 +-------------------+
 | Removed functions |
 +-------------------+
 
 
 
 +---------------+
 | New functions |
 +---------------+
 
 Schema................+ public
 Name..................+ foo
 Argument data types...+ 
 Result data type......+ boolean
 Language..............+ plpgsql
 Type..................+ normal
 Volatility............+ VOLATILE
 Owner.................+ joel
 Source code (chars)...+ 33
 
 
 +-------------------------------+
 | Updated or replaced functions |
 +-------------------------------+
 
 MD5 of changes: df62b14663c69887574cc320a2e20d78
(1 row)


-- 2. If the changes were expected and you feel it is safe to commit for real, copy/paste the MD5 sum and pass it as second argument:
SELECT Deploy($DEPLOY$
CREATE OR REPLACE FUNCTION Foo() RETURN BOOLEAN AS $BODY$
DECLARE
BEGIN
RETURN TRUE;
END;
$BODY$ LANGUAGE plpgsql VOLATILE;
$DEPLOY$, 'df62b14663c69887574cc320a2e20d78');

