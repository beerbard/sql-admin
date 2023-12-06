CREATE  PROC [dbo].[sp_MonitorRepeatedIPsAndEmailAddresses]
(
	
	@TimeElapsedWindow int = 2,
	--@SecondsThreshold		int = 2,
	@Threshold int = 8,
	@AllowDebug bit = 0
	
)
	
AS

/* 
	THIS PROC IS CALLED FROM THE Nagios alerting system, once every minute. It queries the tables for any suspicious repeated failed donation 
	calls and returns IP address or Email addresses of the requests that is trying to 
	hack us.  The condition is more than [threshold] number of "failed" requests
	coming from the same IP or email address.

*/

BEGIN
	declare @DateFrom DateTime2;    
	declare @DateTo DateTime2; 
	declare @ToFlag bit; 
	declare @ErrNo int 
	declare @IPAddresses varchar(8000) = ''
	declare @EmailAddresses varchar(8000) ='';
	declare @outputMessage varchar(8000) ='';

	SET @DateTo = DATEADD(mi, DATEDIFF(mi, 0, CURRENT_TIMESTAMP), 0)
	SET @DateFrom = DATEADD(mi,-@TimeElapsedWindow, @DateTo) 
	SET @outputMessage = 'CRITICAL: Repeated failed requests received from '
	
	if (@AllowDebug = 1)    
	begin    
		print '@DateFrom=' + cast(@DateFrom as varchar(50));    
		print '@DateTo=' + cast(@DateTo as varchar(50));   
	end    
	
	SELECT @IPAddresses = @IPAddresses + ',' +  VC_DONOR_IP 
		FROM [dbo].[NagiosChargeStatusFailures] n  (nolock)			
		WHERE n.d_added BETWEEN @DateFrom AND @DateTo AND VC_DONOR_IP <> ''
		GROUP BY  VC_DONOR_IP 	HAVING 	COUNT(1) > 	@Threshold

		
		SELECT @EmailAddresses= @EmailAddresses + ',' + VC_DONOR_EMAIL
		FROM [dbo].[NagiosChargeStatusFailures] n  (nolock)				
		WHERE n.d_added BETWEEN @DateFrom AND @DateTo AND VC_DONOR_EMAIL <> ''
		GROUP BY  VC_DONOR_EMAIL HAVING 
		COUNT(1) > 	@Threshold	

	IF LEFT(@IPAddresses, 1)=','
	BEGIN
		SET @IPAddresses = SUBSTRING(@IPAddresses, 2, len(@IPAddresses))
	END	
	IF LEFT(@EmailAddresses, 1)=','
	BEGIN
		SET @EmailAddresses = SUBSTRING(@EmailAddresses, 2, len(@EmailAddresses))
	END		

	--Ignore IP and/or email address if already blacklisted
	IF EXISTS (SELECT 1 FROM dbo.TBL_BLOCKED_TRANSACTION_CHARACTERISTICS tbtc (NOLOCK)
				WHERE tbtc.VC_TRANSACTION_CHARACTERISTIC_TYPE = 'TC_IP' AND tbtc.VC_DATA = @IPAddresses )
	BEGIN
		if (@AllowDebug = 1)    
		begin
			print 'IP address already blacklisted'
		end
		SET @IPAddresses = ''
	END

	IF EXISTS (SELECT 1 FROM dbo.TBL_BLOCKED_TRANSACTION_CHARACTERISTICS tbtc (NOLOCK)
				WHERE tbtc.VC_TRANSACTION_CHARACTERISTIC_TYPE = 'TC_USER_LOGON_ID' AND tbtc.VC_DATA = @EmailAddresses )
	BEGIN
		if (@AllowDebug = 1)    
		begin
			print 'Email address already blacklisted'
		end
		SET @EmailAddresses = ''
	END

	if len(@IPAddresses) > 0 AND len(@EmailAddresses) > 0
	BEGIN
		set @ToFlag = 1;  
		SET @outputMessage = @outputMessage + 'IPs: ' 
				+ @IPAddresses + ' and email addresses: ' +  @EmailAddresses +'!';
		
		if (@AllowDebug = 1)    
		begin    
			print '@ToFlag= 1';    
			print @outputMessage ;   
		end    
	END
	ELSE IF len(@IPAddresses) > 0
	BEGIN
		set @ToFlag = 1;  
		SET @outputMessage = @outputMessage + 'IPs: ' + @IPAddresses +'!';
		
		if (@AllowDebug = 1)    
		begin    
			print '@ToFlag= 1';    
			print @outputMessage ;   
		end				
	END
	ELSE IF len(@EmailAddresses) > 0
	BEGIN
		set @ToFlag = 1;  
		SET @outputMessage = @outputMessage + 'email addresses: ' +  @EmailAddresses +'!';
		
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
		raiserror('IN [sp_MonitorRepeatedIPsAndEmailAddresses] Some Error-- Errno: %d',     
		11,1, @ErrNo)    
		return -1    
	end    
       
	--Print status of health    
	if (@ToFlag = 0)    
	begin    
		print 'OK: No repeated payflow charge failures detected'    
	end    
	else    
	begin    
		print @outputMessage   
	end    
	return 0    
END

