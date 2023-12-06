CREATE PROCEDURE [dbo].[MonitorLongRunningQueries]
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

	SET @QueryCount = 0
		
	DECLARE ExceptionQueries CURSOR FOR  
	SELECT SearchText, CpuTimeThreshold, ElapsedTimeThreshold
	FROM MonitoringThresholds
	WHERE Enabled = 1
		
	DECLARE HandlesCursor CURSOR FOR  
	SELECT Handle, CpuTime, ElapsedTime 
	FROM @SqlHandles

	DECLARE @CurrentHandle VARBINARY(64)
	DECLARE @CurrentCpuTime INT
	DECLARE @CurrentElapsedTime INT
	
	DECLARE @CurrentPattern VARCHAR(1024)
	DECLARE @ConfiguredCpuThreshold INT
	DECLARE @ConfiguredElapsedThreshold INT
	
	OPEN HandlesCursor   
	FETCH NEXT FROM HandlesCursor INTO @CurrentHandle, @CurrentCpuTime, @CurrentElapsedTime
	WHILE @@FETCH_STATUS = 0   
	BEGIN   

		OPEN ExceptionQueries   

		FETCH NEXT FROM ExceptionQueries INTO @CurrentPattern, @ConfiguredCpuThreshold, @ConfiguredElapsedThreshold 	
		WHILE @@FETCH_STATUS = 0   
		BEGIN
			IF EXISTS( SELECT 1
						FROM @SqlHandles
						WHERE [QueryText] LIKE @CurrentPattern AND
						( @CurrentCpuTime > @ConfiguredCpuThreshold OR
						  @CurrentElapsedTime > @ConfiguredElapsedThreshold)
						)
			BEGIN
				SET @QueryCount = (@QueryCount + 1)
				BREAK;
			END
			
			FETCH NEXT FROM ExceptionQueries INTO @CurrentPattern, @ConfiguredCpuThreshold, @ConfiguredElapsedThreshold 	
		END 		

		CLOSE ExceptionQueries
		
		FETCH NEXT FROM HandlesCursor INTO @CurrentHandle, @CurrentCpuTime, @CurrentElapsedTime
	END   

	CLOSE HandlesCursor   
	
	DEALLOCATE HandlesCursor
	DEALLOCATE ExceptionQueries
	
	
	IF (@QueryCount > 2)    
	BEGIN    
		PRINT 'CRITICAL: There are ' + convert(varchar(10), @QueryCount) + ' queries with CPU time or Elapsed time greater than corresponding threshold'
	END    
	ELSE IF (@QueryCount > 0)    
	BEGIN    
		PRINT 'Warning: There are ' + convert(varchar(10), @QueryCount) + ' queries with CPU time or Elapsed time greater than corresponding threshold'
	END	
	ELSE
	BEGIN
		PRINT 'OK: There are no running queires queries with CPU time or Elapsed time greater than corresponding threshold'
	END    

	IF (@QueryCount > 0)
	BEGIN
		INSERT INTO LoadMonitoring..QueryLog
		SELECT *
		FROM @SqlHandles
	END

	RETURN 0

END

