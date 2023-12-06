CREATE proc [dbo].[GetTokenExpiringPartner]
@Interval int
As
Begin
	declare @StartDate datetime, @EndDate datetime, @Partners varchar(max) 

	set @StartDate = getdate();
	set @EndDate = DATEADD(day,@Interval,@startDate)
	set @Partners = ''

	--drop table #AllPartners
	--drop table #Partners

	SELECT tp.VC_PARTNER_SOURCE, MAX(t.Expiry) Expiry INTO #AllPartners
	FROM [Identity].Token t (NOLOCK)
	JOIN dbo.TBL_PARTNER tp (NOLOCK) ON t.PartnerId = tp.I_PARTNER_ID
	GROUP BY tp.VC_PARTNER_SOURCE
	ORDER BY Expiry

	select distinct VC_PARTNER_SOURCE into #Partners
	from #AllPartners
	where Expiry >= @StartDate and Expiry <= @EndDate

	select @Partners = coalesce(@Partners, '') + VC_PARTNER_SOURCE +';' from #Partners
	--print @Partners

	if @Partners = ''
	begin
		print 'OK: No partners expiring tokens within next ' +  convert(varchar(2), @Interval) + ' days;'   
	end
	else
	begin
		print 'CRITICAL: List of partners ' + @Partners + ' having expiring token within next ' +  convert(varchar(2), @Interval) + ' days;'
	end
end

