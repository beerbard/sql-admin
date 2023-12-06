

BEGIN TRAN

exec sp_rename 
@objname = '[PK_ApiAccess]',
@newname = '[PK_ApiAccess_Archive]'

exec sp_rename 
@objname = '[FK_TBL_API_ACCESS_LOG_ApiErrorCategory]',
@newname = '[FK_TBL_API_ACCESS_LOG_ApiErrorCategory_Archive]'

exec sp_rename 
@objname = '[FK_TBL_API_ACCESS_LOG_TBL_API_CATEGORY]',
@newname = '[FK_TBL_API_ACCESS_LOG_TBL_API_CATEGORY_Archive]'

exec sp_rename 
@objname = '[FK_TBL_API_ACCESS_LOG_TBL_API_METHOD_TYPE]',
@newname = '[FK_TBL_API_ACCESS_LOG_TBL_API_METHOD_TYPE_Archive]'

exec sp_rename 
@objname = '[TBL_API_ACCESS_LOG_UPDATE_TIMESTAMP_TRIGGER]',
@newname = '[TBL_API_ACCESS_LOG_UPDATE_TIMESTAMP_TRIGGER_Archive]'


exec sp_rename 'TBL_API_ACCESS_LOG', 'TBL_API_ACCESS_LOG_ARCHIVE'
go

CREATE TABLE [dbo].[TBL_API_ACCESS_LOG](
	[I_API_ACCESS_ID] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[I_PARTNER_ID] [int] NOT NULL,
	[VC_SERVICE_NAME] [varchar](255) NOT NULL,
	[VC_METHOD_NAME] [varchar](255) NOT NULL,
	[D_ADDED] [datetime] NOT NULL,
	[VC_ADDED_BY] [varchar](64) NOT NULL,
	[D_MODIFIED] [datetime] NOT NULL,
	[I_PARTNER_CAMPAIGN_ID] [int] NULL,
	[VC_PARTNER_SOURCE] [varchar](16) NULL,
	[VC_CAMPAIGN_PARAM] [varchar](32) NULL,
	[VC_USER_NAME] [varchar](32) NULL,
	[VB_PASSWORD] [varbinary](512) NULL,
	[VC_IP_ADDRESS] [varchar](40) NULL,
	[VC_HOST_SERVER] [varchar](64) NULL,
	[B_ISSUCCESS] [bit] NULL,
	[VC_MODIFIED_BY] [varchar](64) NULL,
	[I_API_CATEGORY_ID] [int] NULL,
	[I_API_METHOD_TYPE_ID] [int] NULL,
	[B_ISPROCESSED] [bit] NULL,
	[XML_RESPONSE_MESSAGE] [nvarchar](max) NULL,
	[XML_REQUEST_MESSAGE] [nvarchar](max) NULL,
	[VC_STATUS] [varchar](64) NULL,
	[ApiErrorCategoryId] [int] NULL,
	[ExecutionTimeMs] [int] NULL,
 CONSTRAINT [PK_ApiAccess] PRIMARY KEY CLUSTERED 
(
	[I_API_ACCESS_ID] ASC
)WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

EXEC sys.sp_bindefault @defname=N'[dbo].[NOW]', @objname=N'[dbo].[TBL_API_ACCESS_LOG].[D_ADDED]' , @futureonly='futureonly'
GO
EXEC sys.sp_bindefault @defname=N'[dbo].[HOSTNAME]', @objname=N'[dbo].[TBL_API_ACCESS_LOG].[VC_ADDED_BY]' , @futureonly='futureonly'
GO
EXEC sys.sp_bindefault @defname=N'[dbo].[NOW]', @objname=N'[dbo].[TBL_API_ACCESS_LOG].[D_MODIFIED]' , @futureonly='futureonly'
GO
EXEC sys.sp_bindefault @defname=N'[dbo].[FALSE]', @objname=N'[dbo].[TBL_API_ACCESS_LOG].[B_ISSUCCESS]' , @futureonly='futureonly'
GO
EXEC sys.sp_bindefault @defname=N'[dbo].[FALSE]', @objname=N'[dbo].[TBL_API_ACCESS_LOG].[B_ISPROCESSED]' , @futureonly='futureonly'
GO

ALTER TABLE [dbo].[TBL_API_ACCESS_LOG]  WITH CHECK ADD  CONSTRAINT [FK_TBL_API_ACCESS_LOG_ApiErrorCategory] FOREIGN KEY([ApiErrorCategoryId])
REFERENCES [dbo].[ApiErrorCategory] ([ApiErrorCategoryId])
GO

ALTER TABLE [dbo].[TBL_API_ACCESS_LOG] CHECK CONSTRAINT [FK_TBL_API_ACCESS_LOG_ApiErrorCategory]
GO

ALTER TABLE [dbo].[TBL_API_ACCESS_LOG]  WITH NOCHECK ADD  CONSTRAINT [FK_TBL_API_ACCESS_LOG_TBL_API_CATEGORY] FOREIGN KEY([I_API_CATEGORY_ID])
REFERENCES [dbo].[TBL_API_CATEGORY] ([I_API_CATEGORY_ID])
NOT FOR REPLICATION 
GO

ALTER TABLE [dbo].[TBL_API_ACCESS_LOG] CHECK CONSTRAINT [FK_TBL_API_ACCESS_LOG_TBL_API_CATEGORY]
GO

ALTER TABLE [dbo].[TBL_API_ACCESS_LOG]  WITH NOCHECK ADD  CONSTRAINT [FK_TBL_API_ACCESS_LOG_TBL_API_METHOD_TYPE] FOREIGN KEY([I_API_METHOD_TYPE_ID])
REFERENCES [dbo].[TBL_API_METHOD_TYPE] ([I_API_METHOD_TYPE_ID])
NOT FOR REPLICATION 
GO

ALTER TABLE [dbo].[TBL_API_ACCESS_LOG] CHECK CONSTRAINT [FK_TBL_API_ACCESS_LOG_TBL_API_METHOD_TYPE]
GO

CREATE TRIGGER [dbo].[TBL_API_ACCESS_LOG_UPDATE_TIMESTAMP_TRIGGER] 
on [dbo].[TBL_API_ACCESS_LOG] for update 
as
begin
	if UPDATE(VC_MODIFIED_BY) begin
		return
	end

	update TBL_API_ACCESS_LOG
	set
		D_MODIFIED = getdate(), 
		VC_MODIFIED_BY = HOST_NAME()
	from
		TBL_API_ACCESS_LOG  TABU, 
		inserted I
	where 
		TABU.I_API_ACCESS_ID = I.I_API_ACCESS_ID
end
GO

ALTER TABLE [dbo].[TBL_API_ACCESS_LOG] ENABLE TRIGGER [TBL_API_ACCESS_LOG_UPDATE_TIMESTAMP_TRIGGER]
GO

--rollback tran
commit tran
