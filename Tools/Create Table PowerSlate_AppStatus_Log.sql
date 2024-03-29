USE [PowerCampusMapper]
GO

/****** Object:  Table [dbo].[PowerSlate_AppStatus_Log_test]    Script Date: 2/18/2021 3:50:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PowerSlate_AppStatus_Log](
	[ApplicationNumber] [uniqueidentifier] NULL,
	[ProspectId] [uniqueidentifier] NULL,
	[FirstName] [nvarchar](50) NULL,
	[LastName] [nvarchar](50) NULL,
	[ComputedStatus] [nvarchar](50) NULL,
	[Notes] [nvarchar](max) NULL,
	[RecruiterApplicationStatus] [int] NULL,
	[ApplicationStatus] [int] NULL,
	[PEOPLE_CODE_ID] [nvarchar](10) NULL,
	[UpdateTime] [datetime2](7) NULL,
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Ref] [nvarchar](16) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[PowerSlate_AppStatus_Log] ADD  CONSTRAINT [PowerSlate_AppStatus_Log_UpdateTime]  DEFAULT (getdate()) FOR [UpdateTime]
GO

