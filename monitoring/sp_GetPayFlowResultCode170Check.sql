CREATE PROCEDURE [dbo].[sp_GetPayFlowResultCode170Check](     
	@TimeElapsedWindow int = 3,
	@AllowDebug bit = 0,
	@ResultCode int 
)
	
AS

/*

This sproc is called by Nagios alerting system. It basically flags a pager alert if we record a Payflow Response code of 170 (carding fraud!)

*/

BEGIN
	declare @DateFrom DateTime2 = CURRENT_TIMESTAMP;    
	declare @DateTo DateTime2; 
	declare @ToFlag bit; 
	declare @ErrNo int 

	SET @DateTo = CURRENT_TIMESTAMP; 	
	        
	SET @DateFrom = DATEADD(minute,-@TimeElapsedWindow,@DateTo); 
	
	if (@AllowDebug = 1)    
	begin    
		print '@DateFrom=' + cast(@DateFrom as varchar(50));    
		print '@DateTo=' + cast(@DateTo as varchar(50));   
	end    
	
	--set @DateFrom = '2019-07-31 10:02 AM'
	--set @DateTo = '2019-07-31 10:04 AM'

	IF EXISTS(
			SELECT 1 FROM dbo.NagiosPayflowErrorAlert (nolock) where I_Result_code=@ResultCode
			AND  d_added between  @DateFrom AND @DateTo)
	BEGIN
		set @ToFlag = 1;  
		if (@AllowDebug = 1)    
		begin    
			print '@ToFlag= 1';    
			print 'NOT OK.  CRITICAL: Payflow Account transactions blocked!';   
		end    
	END
	ELSE
	BEGIN
		set @ToFlag = 0;
		if (@AllowDebug = 1)    
		begin    
			print '@ToFlag= 0';    
			print 'Everything OK';      
		end   		
	END	

	select @ErrNo = @@ERROR    
      
	if @ErrNo <> 0 begin    
		--rollback transaction    
		raiserror('IN sp_GetPayFlowResultCodeCheck Some Error-- Errno: %d',     
		11,1, @ErrNo)    
		return -1    
	end    
    
	--commit transaction    
     
     
	--Print status of health    
	if (@ToFlag = 0)    
	begin    
		print 'OK: Payflow Account transactions not blocked'    
	end    
	else    
	begin    
		print 'CRITICAL: Payflow Account transactions blocked!'    
	end    
	return 0    
END

