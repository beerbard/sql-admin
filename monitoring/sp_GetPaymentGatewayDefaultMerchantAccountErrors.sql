CREATE PROCEDURE [dbo].[sp_GetPaymentGatewayDefaultMerchantAccountErrors]
(     
	@TimeElapsedWindow int = 2,
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
	declare @intDefaultMerchantAccountUnavailable int

	SET @DateTo = CURRENT_TIMESTAMP; 	
	SET @DateFrom = DATEADD(minute,-@TimeElapsedWindow,@DateTo); 
	
	set @intDefaultMerchantAccountUnavailable = 0

	-- get DeviceDataInvalid - count
	select @intDefaultMerchantAccountUnavailable = count(1)
	from PaymentGatewayErrorAlert
	where [type] = 'DefaultMerchantAccountUnavailable'
	and AddedDate >= @DateFrom and AddedDate < @DateTo

	--Print status of health
	if (isnull(@intDefaultMerchantAccountUnavailable,0) = 0 )
	begin    
		print 'OK: No Errors for - DefaultMerchantAccountUnavailable.'    
	end    
	else    
	begin    
		print 'CRITICAL: Error - DefaultMerchantAccountUnavailable - ' + convert(varchar(4), @intDefaultMerchantAccountUnavailable) 
	end    
	
	select @ErrNo = @@ERROR    
      
	if @ErrNo <> 0 begin    
		--rollback transaction    
		raiserror('IN [sp_GetPaymentGatewayDefaultMerchantAccountErrors] Some Error-- Errno: %d',     
		11,1, @ErrNo)    
		return -1    
	end    
    
	return 0    
END

