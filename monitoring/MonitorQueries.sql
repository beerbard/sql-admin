CREATE PROCEDURE [dbo].[MonitorQueries]
(	
	@CpuTimeThreshold int,
	@ElapsedTimeThreshold int
) 
AS	
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @SqlHandles TABLE (LogDateTime DATETIME, DatabaseName VARCHAR(128), 
	Handle VARBINARY(64), QueryText NVARCHAR(MAX), CpuTime INT, ElapsedTime INT)

	DECLARE @QueryCount INT

	INSERT INTO @SqlHandles
	SELECT  GETDATE(),
			DB_NAME(),
			r.sql_handle,
			t.text,
			r.cpu_time,
			DATEDIFF(ms, r.start_time, getdate())
	FROM    sys.dm_exec_requests r
	OUTER APPLY sys.dm_exec_sql_text(sql_handle) t
	WHERE	database_id = db_id() AND
			(r.cpu_time >= @CpuTimeThreshold OR
			DATEDIFF(ms, r.start_time, getdate()) >= @ElapsedTimeThreshold) AND
			sql_handle IS NOT NULL

	SELECT @QueryCount = COUNT(1) 
	FROM @SqlHandles
		
	DECLARE ExceptionQueries CURSOR FOR  
	SELECT SearchText
	FROM MonitoringThresholds
	WHERE Enabled = 1
		
	DECLARE HandlesCursor CURSOR FOR  
	SELECT Handle 
	FROM @SqlHandles

	DECLARE @CurrentHandle VARBINARY(64)
	DECLARE @CurrentPattern VARCHAR(1024)
	DECLARE @SkipQuery BIT
	
	OPEN HandlesCursor   
	FETCH NEXT FROM HandlesCursor INTO @CurrentHandle   
	WHILE @@FETCH_STATUS = 0   
	BEGIN   

		OPEN ExceptionQueries   

		FETCH NEXT FROM ExceptionQueries INTO @CurrentPattern 	
		WHILE @@FETCH_STATUS = 0   
		BEGIN
			IF EXISTS( SELECT 1
						FROM @SqlHandles
						WHERE QueryText LIKE @CurrentPattern )
			BEGIN
				SET @QueryCount = (@QueryCount - 1)
				BREAK;
			END
			
			FETCH NEXT FROM ExceptionQueries INTO @CurrentPattern 
		END 		

		CLOSE ExceptionQueries
		
		FETCH NEXT FROM HandlesCursor INTO @CurrentHandle
	END   

	CLOSE HandlesCursor   
	
	DEALLOCATE HandlesCursor
	DEALLOCATE ExceptionQueries
	
	
	IF (@QueryCount > 2)    
	BEGIN    
		PRINT 'CRITICAL: There are ' + convert(varchar(10), @QueryCount) + ' queries with CPU time greater than ' + convert(varchar(10), @CpuTimeThreshold) + ' ms or Elapsed time greater than ' + convert(varchar(10), @ElapsedTimeThreshold) + 'ms'
	END    
	ELSE IF (@QueryCount > 0)    
	BEGIN    
		PRINT 'Warning: There are ' + convert(varchar(10), @QueryCount) + ' queries with CPU time greater than ' + convert(varchar(10), @CpuTimeThreshold) + 'ms or Elapsed time greater than ' + convert(varchar(10), @ElapsedTimeThreshold) + 'ms'
	END	
	ELSE
	BEGIN
		PRINT 'OK: There are no running queires with CPU time greater than ' + convert(varchar(10), @CpuTimeThreshold) + 'ms or Elapsed time greater than ' + convert(varchar(10), @ElapsedTimeThreshold) + 'ms'
	END   
	
	 IF (@QueryCount > 0)
	 BEGIN
		INSERT INTO LoadMonitoring..QueryLog
		SELECT *
		FROM @SqlHandles
	 END
	RETURN 0

END

