Create PROCEDURE [dbo].[sp_GetSystemError]  

as    

declare @ErrNo int    

begin    

	SET NOCOUNT ON    

	declare @CurrentFailureCount int;    

	declare @DateFrom DateTime;    

	declare @DateTo DateTime;    



	SET @CurrentFailureCount = 0;    

	SET @DateTo = CURRENT_TIMESTAMP;    

	SET @DateFrom = DATEADD (minute,-2, @DateTo);    -- set from time less than 1 minute from current timestamp



	--Get SystemError count


	SELECT @CurrentFailureCount= COUNT(B_ISSUCCESS)    

	FROM TBL_API_ACCESS_LOG    

	WHERE B_ISSUCCESS = 0    

	AND VC_METHOD_NAME <> 'CheckNpoEligibilityRest'

	AND D_ADDED BETWEEN @DateFrom and @DateTo

	AND VC_STATUS = 'SystemError'


	-- check for error    

	select @ErrNo = @@ERROR 

	if @ErrNo <> 0 

	begin    

		raiserror('IN sp_GetSystemError Some Error-- Errno: %d', 11,1, @ErrNo)    

		return -1    

	end    


	--Print status of health    

	if @CurrentFailureCount = 0

	begin    

		print 'OK: No System Error found.'    
		

	end    

	else    

	begin    

		print 'CRITICAL: Number of System Error found in last 2 minute is : ' + convert(varchar(10),@CurrentFailureCount) + '.'

		exec MonitorQueries 500, 500
	end    


	return 0    


end

