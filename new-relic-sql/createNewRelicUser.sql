USE master;
    CREATE LOGIN newrelic WITH PASSWORD = '<get password from LastPass>'; --insert new password here
    GRANT CONNECT SQL TO newrelic;
    GRANT VIEW SERVER STATE TO newrelic;
    GRANT VIEW ANY DEFINITION TO newrelic;

DECLARE @name SYSNAME
    DECLARE db_cursor CURSOR 
    READ_ONLY FORWARD_ONLY
    FOR
    SELECT NAME
    FROM master.sys.databases
    WHERE NAME NOT IN ('master','msdb','tempdb','model','rdsadmin','distribution')
    OPEN db_cursor
    FETCH NEXT FROM db_cursor INTO @name WHILE @@FETCH_STATUS = 0
    BEGIN
        EXECUTE('USE "' + @name + '"; CREATE USER newrelic FOR LOGIN newrelic;' );
        FETCH next FROM db_cursor INTO @name
    END
    CLOSE db_cursor
    DEALLOCATE db_cursor