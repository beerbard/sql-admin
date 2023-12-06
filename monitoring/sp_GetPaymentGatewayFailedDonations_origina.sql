CREATE PROCEDURE [dbo].[sp_GetPaymentGatewayFailedDonations]
(     
	@TimeElapsedWindow int = 2,
	@GatewayId int,
	@FailedThreshold int,
	@AllowDebug bit = 0
)
	
AS

/*

This sproc is called by Nagios alerting system. It basically checks if an exception has occured in the Gateway service failure exception.

*/

BEGIN
	declare @DateFrom DateTime2 = CURRENT_TIMESTAMP;    
	declare @DateTo DateTime2; 
	declare @ToFlag bit; 
	declare @ErrNo int
	declare @intFailedCount int
	declare @GatewayName varchar(20)

	SET @DateTo = CURRENT_TIMESTAMP; 	
	SET @DateFrom = DATEADD(minute,-@TimeElapsedWindow,@DateTo); 
	
	
	-- get @intFailedCount - count
	select @intFailedCount = count(I_CHARGE_ID)
	from NagiosChargeStatusFailures
	where PaymentGatewayId = @GatewayId
	and D_ADDED >= @DateFrom and D_ADDED < @DateTo

	-- get gateway name
	select @GatewayName = name from PaymentGateway where Id = @GatewayId

	--Print status of health
	if (isnull(@intFailedCount,0) < @FailedThreshold)
	begin    
		print 'OK: Faild donations are under threshold for gateway '  + @GatewayName    
	end    
	else    
	begin    
		print 'CRITICAL: Error - ' + convert(varchar(4), @intFailedCount) + ' Failed donations -'  + ' for gateway '  + @GatewayName + ' from last ' + convert(varchar(4), @TimeElapsedWindow) +  ' minutes' 
	end    
	
	select @ErrNo = @@ERROR    
      
	if @ErrNo <> 0 begin    
		--rollback transaction    
		raiserror('IN [sp_GetPaymentGatewayFailedDonations] Some Error-- Errno: %d',     
		11,1, @ErrNo)    
		return -1    
	end    
    
	return 0    
END

