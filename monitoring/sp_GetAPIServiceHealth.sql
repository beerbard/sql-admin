CREATE PROCEDURE [dbo].[sp_GetAPIServiceHealth](  
    @ServiceName VARCHAR(100)= NULL,    
	@PartnerName VARCHAR(100)= NULL,    
	@ServerName VARCHAR(255) = NULL,    
	@TimeElapsedWindow int = 30,    
	@ThresholdLimit int = 5,    
	@ThresholdPercentage int = 0,    
	@AllowDebug bit = 0,  
    @APIMethodType VARCHAR(255) = NULL,    
    @ExludeMethods varchar(max) =NULL)    
    
as    
declare @ErrNo int    
begin    
	SET NOCOUNT ON    
	--begin transaction    
	 
	declare @CurrentFailureCount int;    
	declare @TotalCount int;    
	declare @ToFlag bit;    
	declare @DateFrom DateTime;    
	declare @DateTo DateTime;    
	declare @PercCalculated Decimal;    
	declare @APIMethodTypeid int;  
	declare @PaypalMsg varchar(MAX);

	SET @CurrentFailureCount = 0;    
	SET @TotalCount = 0;    
	SET @ToFlag = 0;    
	SET @DateTo = CURRENT_TIMESTAMP;    
	SET @APIMethodTypeId = NULL;  
   
   	IF (@ExludeMethods IS NOT NULL AND (@ExludeMethods='' OR @ExludeMethods='None'))  
	BEGIN  
		SET @ExludeMethods = NULL;  
	END  
	IF (@APIMethodType IS NOT NULL or @APIMethodType != '')  
	BEGIN  
		SELECT @APIMethodTypeId = I_API_METHOD_TYPE_ID FROM dbo.TBL_API_METHOD_TYPE where VC_API_METHOD_TYPE = @APIMethodType;  
	END  
  
    --If null Default is RealTimeDonationProcessing   
	IF (@APIMethodTypeId IS null or @APIMethodTypeId = 0)  
	BEGIN  
		SELECT @APIMethodTypeId = I_API_METHOD_TYPE_ID FROM dbo.TBL_API_METHOD_TYPE where VC_API_METHOD_TYPE = 'RealTimeDonationProcessing';  
	END  
	--Else use the specified API method Type  
   
    --Find the start DateTime based on window frequency    
    SET @DateFrom = DATEADD (minute,-@TimeElapsedWindow,@DateTo);    
    
     
    if (@PartnerName IS NULL or @PartnerName ='' or @PartnerName ='All')     
	begin     
		SET @PartnerName = 'General'    
		--Get Total for a particular service, partner and servername    
		select @TotalCount = count(1)    
		FROM TBL_API_ACCESS_LOG    
		WHERE      
		VC_SERVICE_NAME = @ServiceName    
		AND VC_HOST_SERVER = @ServerName    
		AND I_API_METHOD_TYPE_ID = @APIMethodTypeId   
		AND (@ExludeMethods IS NULL or VC_METHOD_NAME not in (select [String] from dbo.fn_CSVToTable(@ExludeMethods)))  
		AND D_ADDED BETWEEN @DateFrom and @DateTo    

		--Get total failures    
		SELECT @CurrentFailureCount= COUNT(B_ISSUCCESS)    
		FROM TBL_API_ACCESS_LOG    
		WHERE B_ISSUCCESS = 0     
		AND VC_SERVICE_NAME = @ServiceName    
		AND VC_HOST_SERVER = @ServerName    
		AND I_API_METHOD_TYPE_ID = @APIMethodTypeId   
		AND (@ExludeMethods IS NULL or VC_METHOD_NAME not in (select [String] from dbo.fn_CSVToTable(@ExludeMethods)))  
		AND D_ADDED BETWEEN @DateFrom and @DateTo    
	end    
	IF (@ServiceName = 'Paypal')  --Get Total Counts by VCMethodName for Paypal
	BEGIN
		DECLARE @PaypalAll AS TABLE (VC_METHOD_NAME VARCHAR(255), B_ISSUCCESS BIT, TxnCount INT, MaxDateAdded DATETIME)
		DECLARE @PaypalTotal AS TABLE (VC_METHOD_NAME VARCHAR(255), TotalCount INT, FailureCount INT, Perc DECIMAL, LastFailedDate DATETIME NULL, LastSuccessDate DATETIME NULL)
		
		INSERT INTO @PaypalAll
		SELECT VC_METHOD_NAME, B_ISSUCCESS, COUNT(1) AS TxnCount, MAX(D_ADDED) AS MaxDateAdded
		FROM TBL_API_ACCESS_LOG (NOLOCK)   
		WHERE VC_SERVICE_NAME = @ServiceName    
			AND vc_partner_source = @PartnerName    
			AND VC_HOST_SERVER = @ServerName   
			AND I_API_METHOD_TYPE_ID = @APIMethodTypeId    
			AND (@ExludeMethods IS NULL or VC_METHOD_NAME not in (select [String] from dbo.fn_CSVToTable(@ExludeMethods)))  
			AND D_ADDED BETWEEN @DateFrom and @DateTo  
		GROUP BY VC_METHOD_NAME, B_ISSUCCESS

		INSERT INTO @PaypalTotal
		SELECT pa.VC_METHOD_NAME
			, SUM(pa.TxnCount) AS TotalCount
			, ISNULL((SELECT SUM(pa2.TxnCount) FROM @PaypalAll pa2 WHERE pa2.VC_METHOD_NAME = pa.VC_METHOD_NAME AND pa2.B_ISSUCCESS = 0),0) AS FailureCount
			, 0 AS Perc
			, (SELECT MAX(pa3.MaxDateAdded) FROM @PaypalAll pa3 WHERE pa3.VC_METHOD_NAME = pa.VC_METHOD_NAME AND pa3.B_ISSUCCESS = 0) AS LastFailedDate
			, (SELECT MAX(pa4.MaxDateAdded) FROM @PaypalAll pa4 WHERE pa4.VC_METHOD_NAME = pa.VC_METHOD_NAME AND pa4.B_ISSUCCESS = 1) AS LastSuccessDate
		FROM @PaypalAll pa
		GROUP BY pa.VC_METHOD_NAME

		UPDATE pt
		SET pt.Perc = (cast(pt.FailureCount as decimal) / cast(pt.TotalCount as decimal)) * 100
		FROM @PaypalTotal pt

		SELECT @TotalCount = 0, @CurrentFailureCount = 0
		SELECT TOP 1 
			@TotalCount = pt.TotalCount
			,@CurrentFailureCount = pt.FailureCount
		FROM @PaypalTotal pt
		WHERE pt.Perc >= @ThresholdPercentage
		AND pt.LastFailedDate > pt.LastSuccessDate
		
		--SELECT @PaypalMsg = 
		--	STUFF((SELECT ', ' + CAST(LEFT(pt.VC_METHOD_NAME,30) AS VARCHAR(30)) + '(' + CAST(pt.FailureCount AS VARCHAR) + ' of ' + CAST(pt.TotalCount AS VARCHAR) + ') LastFailedOn:' + ISNULL(CONVERT(VARCHAR, pt.LastFailedDate,120),'-') + ' LastSuccessOn:' + IS
NULL(CONVERT(VARCHAR, pt.LastSuccessDate,120),'-')
  --      FROM @PaypalTotal pt
		--WHERE pt.Perc >= @ThresholdPercentage
		--AND pt.LastFailedDate > pt.LastSuccessDate
  --      FOR XML PATH('')) ,1,1,'')
	END
	else    
	begin    
		--Get Total for a particular service, partner and servername    
		select @TotalCount = count(1)    
		FROM TBL_API_ACCESS_LOG    
		WHERE      
		 VC_SERVICE_NAME = @ServiceName    
		 AND vc_partner_source = @PartnerName    
		 AND VC_HOST_SERVER = @ServerName   
		AND I_API_METHOD_TYPE_ID = @APIMethodTypeId    
		AND (@ExludeMethods IS NULL or VC_METHOD_NAME not in (select [String] from dbo.fn_CSVToTable(@ExludeMethods)))  
		 AND D_ADDED BETWEEN @DateFrom and @DateTo    
		   
		--Get total failures    
		SELECT @CurrentFailureCount= COUNT(B_ISSUCCESS)    
		FROM TBL_API_ACCESS_LOG    
		WHERE B_ISSUCCESS = 0     
		 AND VC_SERVICE_NAME = @ServiceName    
		 AND vc_partner_source = @PartnerName    
		 AND VC_HOST_SERVER = @ServerName    
		 AND I_API_METHOD_TYPE_ID = @APIMethodTypeId   
		 AND (@ExludeMethods IS NULL or VC_METHOD_NAME not in (select [String] from dbo.fn_CSVToTable(@ExludeMethods)))  
		 AND D_ADDED BETWEEN @DateFrom and @DateTo    
	end    
     
     
	if (@AllowDebug = 1)    
	begin    
		print '@DateFrom=' + cast(@DateFrom as varchar(50));    
		print '@DateTo=' + cast(@DateTo as varchar(50));    
		print '@TotalCount=' + cast(@TotalCount as varchar(11));    
		print '@ThresholdLimit=' + cast(@ThresholdLimit as varchar(11));    
		print '@CurrentFailureCount=' + cast(@CurrentFailureCount as varchar(11));    
		print '@ThresholdPercentage=' + cast(@ThresholdPercentage as varchar(11));    
		print '@APIMethodType=' + cast(@APIMethodTypeId as varchar(11));    
	end    
     
	--If Threshold met    
	if (@TotalCount >= @ThresholdLimit)    
	begin    
		if (@AllowDebug = 1)    
			print 'THRESHOLD MET';    
		--If % threshold    
		if (@ThresholdPercentage != 0)    
		begin    
			 --If failure greater than @ThresholdPercentage%    
			set @PercCalculated = (cast(@CurrentFailureCount as decimal) / cast(@TotalCount as decimal)) * 100;    
			if (@AllowDebug = 1)    
				print '@ThresholdPercentageCalc=' + cast(@PercCalculated as varchar(11));    
			if(@PercCalculated >= @ThresholdPercentage)    
			begin    
				set @ToFlag = 1;    
				if (@AllowDebug = 1)    
				print 'PERC MET';    
			end    
		end    
		--Check if everything failed    
		else if (@CurrentFailureCount >= @TotalCount)    
		begin    
			set @ToFlag = 1;    
			if (@AllowDebug = 1)    
			print 'ERR MET';    
		end    
	end    
    
 --Mark as scooped rows     
 /*    
 UPDATE APILog SET B_ISPROCESSED = 1    
 FROM TBL_API_ACCESS_LOG AS APILog    
  WHERE B_ISSUCCESS = 0     
   AND B_ISPROCESSED = 0     
   AND VC_SERVICE_NAME = @ServiceName    
   AND VC_PARTNER_SOURCE = @PartnerName    
   AND VC_HOST_SERVER = @ServerName    
 */    
	select @ErrNo = @@ERROR    
      
	if @ErrNo <> 0 begin    
		--rollback transaction    
		raiserror('IN sp_GetAPIServiceHealth Some Error-- Errno: %d',     
		11,1, @ErrNo)    
		return -1    
	end    
    
	--commit transaction    
     
     
	--Print status of health    
	if (@ToFlag = 0)    
	begin    
		print 'OK: Failed donations count below the threshold limit'    
	end    
	else    
	begin    
		--IF (@ServiceName = 'Paypal')
		--	print 'CRITICAL: Failed donations exceeded the threshold limit: ' + @PaypalMsg
		--ELSE
			print 'CRITICAL: Failed donations exceeded the threshold limit'  
	end    
	return 0    
end


