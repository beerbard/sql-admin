Create PROCEDURE [dbo].[sp_GetCapOneRewardDonationStatus]  
as    
declare @ErrNo int    
begin    
	SET NOCOUNT ON    
	--begin transaction    
	 
	declare @TotalCount int;    
	declare @DateFrom DateTime;    
	declare @DateTo DateTime;    
	
	SET @TotalCount = 0;    
	SET @DateTo = CURRENT_TIMESTAMP;    
   
    --Find the start DateTime based on window frequency    
    SET @DateFrom = DATEADD (day,-1,@DateTo);    

	--Get Total for a particular service, partner and servername    
	select @TotalCount = count(1)    
	FROM TBL_API_ACCESS_LOG    
	WHERE      
	VC_SERVICE_NAME = 'CapOneRewardsService2'    
	AND vc_partner_source = 'CAP1'    
	AND VC_METHOD_NAME ='RewardsRedemptionDonation'
	AND D_ADDED BETWEEN @DateFrom and @DateTo    
	   
	
	select @ErrNo = @@ERROR    
      
	if @ErrNo <> 0 begin    
		raiserror('IN sp_GetCapOneRewardDonationStatus Some Error-- Errno: %d',11,1, @ErrNo)    
		return -1    
	end    
    
	if (@TotalCount > 0)    
	begin    
		print 'OK: Donations count are = '+cast(@TotalCount as varchar(11));
	end    
	else    
	begin    
		print 'CRITICAL: NO Donations recorded'; 
	end    
	return 0    
end


