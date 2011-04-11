CREATE OR REPLACE FUNCTION Deploy(
OUT Changes text,
_SQL text,
_MD5 char(32)
) RETURNS TEXT AS $BODY$
DECLARE
_DeployID integer;
_FunctionID oid;
_RemovedFunctionID oid;
_NewFunctionID oid;
_Schema text;
_FunctionName text;
_Diff text;
_ record;
_CountRemoved integer;
_CountNew integer;
_ReplacedFunctions integer[][];
BEGIN

    BEGIN

        RAISE DEBUG 'Creating FunctionsBefore';
        CREATE TEMP TABLE FunctionsBefore ON COMMIT DROP AS
        SELECT * FROM View_Functions;
        
        EXECUTE _SQL;
        
        RAISE DEBUG 'Creating FunctionsAfter';
        CREATE TEMP TABLE FunctionsAfter ON COMMIT DROP AS
        SELECT * FROM View_Functions;
        
        RAISE DEBUG 'Creating AllFunctions';
        CREATE TEMP TABLE AllFunctions ON COMMIT DROP AS
        SELECT FunctionID, Schema, Name FROM FunctionsAfter
        UNION
        SELECT FunctionID, Schema, Name FROM FunctionsBefore;
        
        RAISE DEBUG 'Creating NewFunctions';
        CREATE TEMP TABLE NewFunctions ON COMMIT DROP AS
        SELECT FunctionID FROM FunctionsAfter
        EXCEPT
        SELECT FunctionID FROM FunctionsBefore;
        
        RAISE DEBUG 'Creating RemovedFunctions';
        CREATE TEMP TABLE RemovedFunctions ON COMMIT DROP AS
        SELECT FunctionID FROM FunctionsBefore
        EXCEPT
        SELECT FunctionID FROM FunctionsAfter;
        
        RAISE DEBUG 'Creating ReplacedFunctions';
        CREATE TEMP TABLE ReplacedFunctions (
        RemovedFunctionID oid,
        NewFunctionID oid
        ) ON COMMIT DROP;
        
        FOR _ IN SELECT DISTINCT FunctionsAfter.Schema, FunctionsAfter.Name
        FROM RemovedFunctions, NewFunctions, FunctionsBefore, FunctionsAfter
        WHERE FunctionsBefore.FunctionID  = RemovedFunctions.FunctionID
        AND   FunctionsAfter.FunctionID   = NewFunctions.FunctionID
        AND   FunctionsBefore.Schema      = FunctionsAfter.Schema
        AND   FunctionsBefore.Name        = FunctionsAfter.Name
        LOOP
            SELECT COUNT(*) INTO _CountRemoved FROM RemovedFunctions
            INNER JOIN FunctionsBefore USING (FunctionID)
            WHERE FunctionsBefore.Schema = _.Schema AND FunctionsBefore.Name = _.Name;
        
            SELECT COUNT(*) INTO _CountNew FROM NewFunctions
            INNER JOIN FunctionsAfter USING (FunctionID)
            WHERE FunctionsAfter.Schema = _.Schema AND FunctionsAfter.Name = _.Name;
        
            IF _CountRemoved = 1 AND _CountNew = 1 THEN
                -- Exactly one function removed with identical name as a new function
        
                SELECT RemovedFunctions.FunctionID INTO STRICT _RemovedFunctionID FROM RemovedFunctions
                INNER JOIN FunctionsBefore USING (FunctionID)
                WHERE FunctionsBefore.Schema = _.Schema AND FunctionsBefore.Name = _.Name;
        
                SELECT NewFunctions.FunctionID INTO STRICT _NewFunctionID FROM NewFunctions
                INNER JOIN FunctionsAfter USING (FunctionID)
                WHERE FunctionsAfter.Schema = _.Schema AND FunctionsAfter.Name = _.Name;
        
                INSERT INTO ReplacedFunctions (RemovedFunctionID,NewFunctionID) VALUES (_RemovedFunctionID,_NewFunctionID);
            END IF;
        END LOOP;
        
        RAISE DEBUG 'Deleting ReplacedFunctions from RemovedFunctions';
        DELETE FROM RemovedFunctions WHERE FunctionID IN (SELECT RemovedFunctionID FROM ReplacedFunctions);
        
        RAISE DEBUG 'Deleting ReplacedFunctions from NewFunctions';
        DELETE FROM NewFunctions     WHERE FunctionID IN (SELECT NewFunctionID     FROM ReplacedFunctions);
        
        RAISE DEBUG 'Creating ChangedFunctions';
        
        CREATE TEMP TABLE ChangedFunctions ON COMMIT DROP AS
        SELECT AllFunctions.FunctionID FROM AllFunctions
        INNER JOIN FunctionsBefore ON (FunctionsBefore.FunctionID = AllFunctions.FunctionID)
        INNER JOIN FunctionsAfter  ON (FunctionsAfter.FunctionID  = AllFunctions.FunctionID)
        WHERE FunctionsBefore.Schema         <> FunctionsAfter.Schema
        OR FunctionsBefore.Name              <> FunctionsAfter.Name
        OR FunctionsBefore.ResultDataType    <> FunctionsAfter.ResultDataType
        OR FunctionsBefore.ArgumentDataTypes <> FunctionsAfter.ArgumentDataTypes
        OR FunctionsBefore.Type              <> FunctionsAfter.Type
        OR FunctionsBefore.Volatility        <> FunctionsAfter.Volatility
        OR FunctionsBefore.Owner             <> FunctionsAfter.Owner
        OR FunctionsBefore.Language          <> FunctionsAfter.Language
        OR FunctionsBefore.Sourcecode        <> FunctionsAfter.Sourcecode
        ;
        
        Changes := '';
        
        RAISE DEBUG 'Removed functions...';
        
        Changes := Changes || '+-------------------+' || E'\n';
        Changes := Changes || '| Removed functions |' || E'\n';
        Changes := Changes || '+-------------------+' || E'\n\n';
        
        FOR _ IN
        SELECT
            RemovedFunctions.FunctionID,
            FunctionsBefore.Schema                                     AS SchemaBefore,
            FunctionsBefore.Name                                       AS NameBefore,
            FunctionsBefore.ArgumentDataTypes                          AS ArgumentDataTypesBefore,
            FunctionsBefore.ResultDataType                             AS ResultDataTypeBefore,
            FunctionsBefore.Language                                   AS LanguageBefore,
            FunctionsBefore.Type                                       AS TypeBefore,
            FunctionsBefore.Volatility                                 AS VolatilityBefore,
            FunctionsBefore.Owner                                      AS OwnerBefore,
            length(FunctionsBefore.Sourcecode)                         AS SourcecodeLength
        FROM RemovedFunctions
        INNER JOIN FunctionsBefore USING (FunctionID)
        ORDER BY 2,3,4,5,6,7,8,9,10
        LOOP
            Changes := Changes || 'Schema................- ' || _.SchemaBefore || E'\n';
            Changes := Changes || 'Name..................- ' || _.NameBefore || E'\n';
            Changes := Changes || 'Argument data types...- ' || _.ArgumentDataTypesBefore || E'\n';
            Changes := Changes || 'Result data type......- ' || _.ResultDataTypeBefore || E'\n';
            Changes := Changes || 'Language..............- ' || _.LanguageBefore || E'\n';
            Changes := Changes || 'Type..................- ' || _.TypeBefore || E'\n';
            Changes := Changes || 'Volatility............- ' || _.VolatilityBefore || E'\n';
            Changes := Changes || 'Owner.................- ' || _.OwnerBefore || E'\n';
            Changes := Changes || 'Source code (chars)...- ' || _.SourcecodeLength || E'\n';
        END LOOP;
        Changes := Changes || E'\n\n';
        
        RAISE DEBUG 'New functions...';
        
        Changes := Changes || '+---------------+' || E'\n';
        Changes := Changes || '| New functions |' || E'\n';
        Changes := Changes || '+---------------+' || E'\n\n';
        
        FOR _ IN
        SELECT
            NewFunctions.FunctionID,
            FunctionsAfter.Schema                                     AS SchemaAfter,
            FunctionsAfter.Name                                       AS NameAfter,
            FunctionsAfter.ArgumentDataTypes                          AS ArgumentDataTypesAfter,
            FunctionsAfter.ResultDataType                             AS ResultDataTypeAfter,
            FunctionsAfter.Language                                   AS LanguageAfter,
            FunctionsAfter.Type                                       AS TypeAfter,
            FunctionsAfter.Volatility                                 AS VolatilityAfter,
            FunctionsAfter.Owner                                      AS OwnerAfter,
            length(FunctionsAfter.Sourcecode)                         AS SourcecodeLength
        FROM NewFunctions
        INNER JOIN FunctionsAfter USING (FunctionID)
        ORDER BY 2,3,4,5,6,7,8,9,10
        LOOP
            Changes := Changes || 'Schema................+ ' || _.SchemaAfter || E'\n';
            Changes := Changes || 'Name..................+ ' || _.NameAfter || E'\n';
            Changes := Changes || 'Argument data types...+ ' || _.ArgumentDataTypesAfter || E'\n';
            Changes := Changes || 'Result data type......+ ' || _.ResultDataTypeAfter || E'\n';
            Changes := Changes || 'Language..............+ ' || _.LanguageAfter || E'\n';
            Changes := Changes || 'Type..................+ ' || _.TypeAfter || E'\n';
            Changes := Changes || 'Volatility............+ ' || _.VolatilityAfter || E'\n';
            Changes := Changes || 'Owner.................+ ' || _.OwnerAfter || E'\n';
            Changes := Changes || 'Source code (chars)...+ ' || _.SourcecodeLength || E'\n';
        END LOOP;
        Changes := Changes || E'\n\n';
        
        RAISE DEBUG 'Updated or replaced functions...';
        
        Changes := Changes || '+-------------------------------+' || E'\n';
        Changes := Changes || '| Updated or replaced functions |' || E'\n';
        Changes := Changes || '+-------------------------------+' || E'\n\n';
        
        FOR _ IN
        SELECT
            ChangedFunctions.FunctionID,
            FunctionsBefore.Schema                                     AS SchemaBefore,
            FunctionsBefore.Name                                       AS NameBefore,
            FunctionsBefore.ArgumentDataTypes                          AS ArgumentDataTypesBefore,
            FunctionsBefore.ResultDataType                             AS ResultDataTypeBefore,
            FunctionsBefore.Language                                   AS LanguageBefore,
            FunctionsBefore.Type                                       AS TypeBefore,
            FunctionsBefore.Volatility                                 AS VolatilityBefore,
            FunctionsBefore.Owner                                      AS OwnerBefore,
            FunctionsAfter.Schema                                      AS SchemaAfter,
            FunctionsAfter.Name                                        AS NameAfter,
            FunctionsAfter.ArgumentDataTypes                           AS ArgumentDataTypesAfter,
            FunctionsAfter.ResultDataType                              AS ResultDataTypeAfter,
            FunctionsAfter.Language                                    AS LanguageAfter,
            FunctionsAfter.Type                                        AS TypeAfter,
            FunctionsAfter.Volatility                                  AS VolatilityAfter,
            FunctionsAfter.Owner                                       AS OwnerAfter,
            Diff(FunctionsBefore.Sourcecode,FunctionsAfter.Sourcecode) AS Diff
        FROM ChangedFunctions
        INNER JOIN FunctionsBefore ON (FunctionsBefore.FunctionID = ChangedFunctions.FunctionID)
        INNER JOIN FunctionsAfter  ON (FunctionsAfter.FunctionID  = ChangedFunctions.FunctionID)
        UNION ALL
        SELECT
            FunctionsAfter.FunctionID,
            FunctionsBefore.Schema                                     AS SchemaBefore,
            FunctionsBefore.Name                                       AS NameBefore,
            FunctionsBefore.ArgumentDataTypes                          AS ArgumentDataTypesBefore,
            FunctionsBefore.ResultDataType                             AS ResultDataTypeBefore,
            FunctionsBefore.Language                                   AS LanguageBefore,
            FunctionsBefore.Type                                       AS TypeBefore,
            FunctionsBefore.Volatility                                 AS VolatilityBefore,
            FunctionsBefore.Owner                                      AS OwnerBefore,
            FunctionsAfter.Schema                                      AS SchemaAfter,
            FunctionsAfter.Name                                        AS NameAfter,
            FunctionsAfter.ArgumentDataTypes                           AS ArgumentDataTypesAfter,
            FunctionsAfter.ResultDataType                              AS ResultDataTypeAfter,
            FunctionsAfter.Language                                    AS LanguageAfter,
            FunctionsAfter.Type                                        AS TypeAfter,
            FunctionsAfter.Volatility                                  AS VolatilityAfter,
            FunctionsAfter.Owner                                       AS OwnerAfter,
            Diff(FunctionsBefore.Sourcecode,FunctionsAfter.Sourcecode) AS Diff
        FROM ReplacedFunctions
        INNER JOIN FunctionsBefore ON (FunctionsBefore.FunctionID = ReplacedFunctions.RemovedFunctionID)
        INNER JOIN FunctionsAfter  ON (FunctionsAfter.FunctionID  = ReplacedFunctions.NewFunctionID)
        ORDER BY 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
        LOOP
            IF _.SchemaBefore = _.SchemaAfter THEN
                Changes := Changes || 'Schema................: ' || _.SchemaAfter || E'\n';
            ELSE
                Changes := Changes || 'Schema................- ' || _.SchemaBefore || E'\n';
                Changes := Changes || 'Schema................+ ' || _.SchemaAfter || E'\n';
            END IF;
        
            IF _.NameBefore = _.NameAfter THEN
                Changes := Changes || 'Name..................: ' || _.NameAfter || E'\n';
            ELSE
                Changes := Changes || 'Name..................- ' || _.NameBefore || E'\n';
                Changes := Changes || 'Name..................+ ' || _.NameAfter || E'\n';
            END IF;
        
            IF _.ArgumentDataTypesBefore = _.ArgumentDataTypesAfter THEN
                Changes := Changes || 'Argument data types...: ' || _.ArgumentDataTypesAfter || E'\n';
            ELSE
                Changes := Changes || 'Argument data types...- ' || _.ArgumentDataTypesBefore || E'\n';
                Changes := Changes || 'Argument data types...+ ' || _.ArgumentDataTypesAfter || E'\n';
            END IF;
        
            IF _.ResultDataTypeBefore = _.ResultDataTypeAfter THEN
                Changes := Changes || 'Result data type......: ' || _.ResultDataTypeAfter || E'\n';
            ELSE
                Changes := Changes || 'Result data type......- ' || _.ResultDataTypeBefore || E'\n';
                Changes := Changes || 'Result data type......+ ' || _.ResultDataTypeAfter || E'\n';
            END IF;
        
            IF _.LanguageBefore = _.LanguageAfter THEN
                Changes := Changes || 'Language..............: ' || _.LanguageAfter || E'\n';
            ELSE
                Changes := Changes || 'Language..............- ' || _.LanguageBefore || E'\n';
                Changes := Changes || 'Language..............+ ' || _.LanguageAfter || E'\n';
            END IF;
        
            IF _.TypeBefore = _.TypeAfter THEN
                Changes := Changes || 'Type..................: ' || _.TypeAfter || E'\n';
            ELSE
                Changes := Changes || 'Type..................- ' || _.TypeBefore || E'\n';
                Changes := Changes || 'Type..................+ ' || _.TypeAfter || E'\n';
            END IF;
        
            IF _.VolatilityBefore = _.VolatilityAfter THEN
                Changes := Changes || 'Volatility............: ' || _.VolatilityAfter || E'\n';
            ELSE
                Changes := Changes || 'Volatility............- ' || _.VolatilityBefore || E'\n';
                Changes := Changes || 'Volatility............+ ' || _.VolatilityAfter || E'\n';
            END IF;
        
            IF _.OwnerBefore = _.OwnerAfter THEN
                Changes := Changes || 'Owner.................: ' || _.OwnerAfter || E'\n';
            ELSE
                Changes := Changes || 'Owner.................- ' || _.OwnerBefore || E'\n';
                Changes := Changes || 'Owner.................+ ' || _.OwnerAfter || E'\n';
            END IF;
        
            Changes := Changes || _.Diff || E'\n\n';
        END LOOP;
        
        IF _MD5 IS NULL THEN
            -- We are testing, raise exception to rollback changes
            RAISE EXCEPTION 'OK';
        ELSIF md5(Changes) = _MD5 THEN
            -- Hash matches, proceed, keep changes
        ELSE
            RAISE EXCEPTION 'ERROR_INVALID_MD5 Invalid MD5, % <> %', md5(Changes), _MD5;
        END IF;

    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM <> 'OK' THEN
            RAISE EXCEPTION '%', SQLERRM;
        END IF;
    END;

    IF _MD5 IS NOT NULL THEN
        INSERT INTO Deploys (SQL,MD5,Diff) VALUES (_SQL,_MD5,Changes) RETURNING DeployID INTO STRICT _DeployID;
    END IF;

    Changes := Changes || 'MD5 of changes: ' || md5(Changes);

RETURN;
END;
$BODY$ LANGUAGE plpgsql VOLATILE;
