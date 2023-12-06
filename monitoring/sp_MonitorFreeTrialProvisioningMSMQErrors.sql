CREATE  PROC [dbo].[sp_MonitorFreeTrialProvisioningMSMQErrors]
(
	
	@TimeElapsedWindow int = 1,	
	@AllowDebug bit = 0
	
)
	
AS

/* 
	THIS PROC IS CALLED FROM THE Nagios alerting system, once every minute. 
	It queries and checks for existence of a row in TBL_Provisioning_API_Log table if a corresponding row
	exists for that NPOID in TBL_NPO_DMS_Free_Trial_Provisioning table. 
	
	if no rows are found in the TBL_Provisioning_API_Log table, it means the request for Free Trial never reached the 
	FreeTrialWindowsService and is stuck in the Outbound queue or it errored out,
	even before it called the DMS API within that service.

	NOTE: A request (Message) is sent and hence a row is inserted into TBL_NPO_DMS_Free_Trial_Provisioning from MyAccount web app.
	      However, A row gets inserted into TBL_Provisioning_API_Log when the message reaches the FreeTrial Windows service. So,
		  If a row is found in the first table and not in the second, fire up the Nagios alert as it could mean MSMQ issues or
		  the FT service is hosed..

*/

BEGIN
	declare @DateFrom DateTime2;    
	declare @DateTo DateTime2; 
	declare @ToFlag bit; 
	declare @ErrNo int 	
	declare @outputMessage varchar(8000) ='';

	SET @DateTo = DATEADD(mi, DATEDIFF(mi, 0, CURRENT_TIMESTAMP), 0)
	SET @DateFrom = DATEADD(mi,-@TimeElapsedWindow, @DateTo) 
	SET @outputMessage = 'CRITICAL: '
	
	if (@AllowDebug = 1)    
	begin    
		print '@DateFrom=' + cast(@DateFrom as varchar(50));    
		print '@DateTo=' + cast(@DateTo as varchar(50));   
	end    
	
	IF EXISTS (SELECT 1 FROM TBL_NPO_DMS_Free_Trial_Provisioning ftp (nolock)
	LEFT JOIN TBL_Provisioning_API_Log apilog (nolock) ON apilog.I_NPO_ID = ftp.I_NPO_ID
	WHERE apilog.I_NPO_ID IS NULL and ftp.FreeTrialSuccessfullyProvisionedDate is null
	and ftp.D_ADDED <=@DateFrom)
	
	BEGIN
		set @ToFlag = 1;  
		SET @outputMessage = @outputMessage + 'A request was made from MyAccount for free trial provisioning. But the FT service has not processed the message. Please verify if the Free Trial service is running and there are no MSMQ isues' ;
		
		if (@AllowDebug = 1)    
		begin    
			print '@ToFlag= 1';    
			print @outputMessage ;   
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
		raiserror('IN [sp_MonitorFreeTrialProvisioningMSMQErrors] Some Error-- Errno: %d',     
		11,1, @ErrNo)    
		return -1    
	end    
       
	--Print status of health    
	if (@ToFlag = 0)    
	begin    
		print 'OK: No Free Trial service or MSMQ Failures detected.'    
	end    
	else    
	begin    
		print @outputMessage   
	end    
	return 0    
END

