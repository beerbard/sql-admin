-- Used to change merchant account mapping for organizations (i.e from Payflow to Braintree)
USE NfgPrimary

INSERT INTO dbo.MerchantAccountHAGroupMapping
(
    --Id - column value is auto-generated
    MerchantAccountHAGroupId,
    I_PARTNER_ID,
    I_PARTNER_CAMPAIGN_ID,
    PaymentMethodTypeId,
    BillingCountryTypeId
)
VALUES
(
    -- Id - int
    1, -- MerchantAccountHAGroupId - int
    100231, -- I_PARTNER_ID - int
    NULL, -- I_PARTNER_CAMPAIGN_ID - int
    1, -- PaymentMethodTypeId - int
    3
)

GO

-- Used to look at donations for a particular time.
    -- Get the charge ID
    select * from tbl_donation where D_ADDED > '8/23/2021'

    -- Use the charge ID to get the status.
    select * from TBL_CHARGE_STATUS where I_CHARGE_ID = 1269492953

-- Used to find iv and key associated to app cert.

    select * from TBL_IV_KEY where i_iv_key_id = #####

    update TBL_IV_KEY set <IV>,<kKEY> where i_iv_key_id = #####

-- Used to set authorized redirects for the Account application. Get urls from existing target environment. 
    select I_PARTNER_API_CUSTOMIZATION_ID, I_PARTNER_ID, AuthFlow, AuthRedirectUris, AuthPostLogoutRedirectUris, LogoutUri
    FROM dbo.TBL_PARTNER_API_CUSTOMIZATION
    where I_PARTNER_API_CUSTOMIZATION_ID IN (10651,10652,10653,10654)

    set AuthRedirectUris = 'http(s)?://account-uat.networkforgood.org/admin/auth/sso-openid/callback'
    where I_PARTNER_API_CUSTOMIZATION_ID IN (10654)

    -- Shouldn't neet to update
    update dbo.TBL_PARTNER_API_CUSTOMIZATION
    set AuthRedirectUris = 'https://account-uat.networkforgood.org/https://apply-uat.networkforgood.org/http://sso.lithiumstaging.networkforgood.org/'
    where I_PARTNER_API_CUSTOMIZATION_ID IN (10646)



    /****** Script for SelectTopNRows command from SSMS  ******/
    SELECT TOP (1000) [I_PARTNER_API_CUSTOMIZATION_ID]
      ,[AuthRedirectUris]
	  ,[AuthPostLogoutRedirectUris]
      ,[LogoutUri]
      
    FROM [NfgPrimary].[dbo].[TBL_PARTNER_API_CUSTOMIZATION]

    where LogoutUri is not NULL

-- Don't know what this does.

    USE NfgPrimary

DECLARE @SearchStr nvarchar(100)
SET @SearchStr = 'networkforgood-beta'
 

CREATE TABLE #Results (ColumnName nvarchar(370), ColumnValue nvarchar(3630))
 
SET NOCOUNT ON
 
DECLARE @TableName nvarchar(256), @ColumnName nvarchar(128), @SearchStr2 nvarchar(110)
SET  @TableName = ''
SET @SearchStr2 = QUOTENAME('%' + @SearchStr + '%','''')
 
WHILE @TableName IS NOT NULL
 
BEGIN
    SET @ColumnName = ''
    SET @TableName = 
    (
        SELECT MIN(QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME))
        FROM     INFORMATION_SCHEMA.TABLES
        WHERE         TABLE_TYPE = 'BASE TABLE'
            AND    QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) > @TableName
            AND    OBJECTPROPERTY(
                    OBJECT_ID(
                        QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME)
                         ), 'IsMSShipped'
                           ) = 0
    )
 
    WHILE (@TableName IS NOT NULL) AND (@ColumnName IS NOT NULL)
         
    BEGIN
        SET @ColumnName =
        (
            SELECT MIN(QUOTENAME(COLUMN_NAME))
            FROM     INFORMATION_SCHEMA.COLUMNS
            WHERE         TABLE_SCHEMA    = PARSENAME(@TableName, 2)
                AND    TABLE_NAME    = PARSENAME(@TableName, 1)
                AND    DATA_TYPE IN ('char', 'varchar', 'nchar', 'nvarchar', 'int', 'decimal')
                AND    QUOTENAME(COLUMN_NAME) > @ColumnName
        )
 
        IF @ColumnName IS NOT NULL
         
        BEGIN
            INSERT INTO #Results
            EXEC
            (
                'SELECT ''' + @TableName + '.' + @ColumnName + ''', LEFT(' + @ColumnName + ', 3630) FROM ' + @TableName + ' (NOLOCK) ' +
                ' WHERE ' + @ColumnName + ' LIKE ' + @SearchStr2
            )
        END
    END   
END
 
SELECT ColumnName, ColumnValue FROM #Results
 
DROP TABLE #Results

GO

-- Used to reassociate users of a DB to existing SQL logins after db restore. 
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-change-users-login-transact-sql?view=sql-server-2017

-- Gets a list of orphaned users on a db - run on the db level. 
EXEC sp_change_users_login @Action='Report'

-- Gets all non-system users of a db and links to local SQL login if it exists.

USE NPORulesEngine --Run for all databases until you can figure out how to get EXEC sp_MSforeachdb to work
GO
EXEC sp_change_users_login 'Report';

declare @userVar varchar(30)
	declare users cursor for select name from sys.database_principals where type = 's';

	open users
	fetch next from users into @userVar
	while @@FETCH_STATUS = 0
	begin
		exec sp_change_users_login 'auto_fix', @userVar -- add , [default db], [password] to add the sql login if it does not exist
		fetch next from users into @userVar
	end
	close users
	deallocate users

-- Attempts at EXEC sp_MSforeachdb query - to be executed as a sqlcmd in script.

-- EXEC sp_MSforeachdb 
--	'use [?];
-- declare @userVar varchar(30)
--	declare users cursor for select name from sys.database_principals where type = ''s'';

--	open users;
--	fetch next from users into @userVar
--	while @@FETCH_STATUS = 0
--	begin
--		exec sp_change_users_login ''auto_fix'', @userVar
--		fetch next from users into @userVar
--	end
--	close users
--	deallocate users'

-- Use this to iterate through partner IDs and update whitelisted addresses if necessary. 
-- In this case (Azure) the firewall uses dynamic addresses to NAT requests to api. Until I figure out how to pass the original requesting URL, we will have to add the 
    -- dynamic IP range to the NfgPrimary database for each partner. 0 and 254 are reserved for network ID and FW ip respectively. 


-- The following script is used to insert permitted IP sources to the TBL_REMOTE_API_ADDRESS in DR - use each time NfgPrimary is restored. 
USE NfgPrimary
	DECLARE @partnerid int
	select @partnerid=min(I_PARTNER_ID) from TBL_REMOTE_API_IP_ADDRESS WHERE I_PARTNER_ID is not null
	while @partnerid is not NULL
    BEGIN
		insert into TBL_REMOTE_API_IP_ADDRESS (I_PARTNER_ID, VC_START_IP_ADDRESS, VC_END_IP_ADDRESS, B_PRODUCTION, B_DISABLED) values (@partnerid, '10.200.3.1', '10.200.3.253', 1, 0)
		-- Find next minimum partner id
        select @partnerid=min(I_PARTNER_ID) from TBL_REMOTE_API_IP_ADDRESS where I_PARTNER_ID > @count and I_PARTNER_ID is not NULL
	END

-- Find all permitted IPs for a certain source

select * from TBL_REMOTE_API_IP_ADDRESS ip join dbo.TBL_PARTNER tp on ip.I_PARTNER_ID = tp.I_PARTNER_ID
where tp.VC_PARTNER_SOURCE = 'NFGWEBSERVICE'
--AND ip.B_DISABLED <> '2' 
AND ip.B_PRODUCTION != '1' 

--where I_PARTNER_ID > @count and I_PARTNER_ID is not NULL
--AND (tp.I_PARTNER_ID = '' OR ip.I_PARTNER_CAMPAIGN_ID in (select i_partner_campaign_id from tbl_partner_campaign where i_partner_id = ''))

-- Update EXISTING ip whitelist entries
update TBL_REMOTE_API_IP_ADDRESS
set B_DISABLED = 0
where I_PARTNER_ID = 100231
AND
VC_START_IP_ADDRESS = '0.0.0.0' 

-- Delete existing ip whitelist entry



-- Find Braintree VC_refid via chargeid. 

select ct.i_charge_id, cta.vc_refid from tbl_charge_transaction_action cta
join TBL_CHARGE_TRANSACTION ct on cta.i_charge_transaction_id = ct.i_charge_transaction_id
where I_CHARGE_ID in (1307139526,1307139527,1307139529) and cta.vc_refid != ''

-- 
select * from UserAction order by 1 desc

-- Test for log running query in DR. In prod, this runs in under 10s.
SELECT [Key] FROM [Identity].[Token] WHERE RevocationDate IS NOT NULL