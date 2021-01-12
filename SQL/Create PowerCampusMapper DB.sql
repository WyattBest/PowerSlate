USE [Recruiter_Dummy]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Datatel_locationExtensionBase] (
	[Datatel_abbreviation] [nvarchar](50) NULL
	,[Datatel_name] [nvarchar](50) NULL
	) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Datatel_prefixExtensionBase] ([Datatel_name] [nchar](10) NULL) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Datatel_stateExtensionBase] (
	[Country] [nvarchar](255) NULL
	,[Datatel_abbreviation] [nvarchar](255) NULL
	,[Datatel_name] [nvarchar](255) NULL
	,[Territory] [nvarchar](255) NULL
	) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Datatel_suffixExtensionBase] ([Datatel_name] [nchar](10) NULL) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Datatel_visatypeExtensionBase] (
	[Datatel_abbreviation] [nvarchar](255) NULL
	,[Datatel_name] [nvarchar](255) NULL
	) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Datatel_academiclevelExtensionBase] (
	[Datatel_abbreviation] [nvarchar](max) NULL
	,[Datatel_name] [nvarchar](max) NULL
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [dbo].[Datatel_academicprogramExtensionBase] (
	[Datatel_abbreviation] [nvarchar](max) NULL
	,[Datatel_name] [nvarchar](max) NULL
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

USE [Recruiter_Dummy]
GO

CREATE TABLE [dbo].[Datatel_academictermExtensionBase] (
	[Datatel_abbreviation] [nvarchar](max) NULL
	,[Datatel_name] [nvarchar](max) NULL
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [dbo].[datatel_applicationstatustypeExtensionBase] (
	[Datatel_name] [nvarchar](max) NULL
	,[Datatel_abbreviation] [nvarchar](max) NULL
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [dbo].[Datatel_citizenshipcodeExtensionBase] (
	[Datatel_name] [nvarchar](255) NULL
	,[Full_Name] [nvarchar](255) NULL
	,[Sort_Name] [nvarchar](255) NULL
	,[FIPS_10_4] [nvarchar](255) NULL
	,[Datatel_abbreviation] [nvarchar](255) NULL
	,[ISO_Alpha3] [nvarchar](255) NULL
	,[Territory] [nvarchar](255) NULL
	,[Continent] [nvarchar](255) NULL
	,[Active] [float] NULL
	) ON [PRIMARY]
GO

CREATE TABLE [dbo].[Datatel_countryExtensionBase] (
	[Datatel_name] [nvarchar](255) NULL
	,[Datatel_abbreviation] [nvarchar](255) NULL
	,[Full_Name] [nvarchar](255) NULL
	,[FIPS_10_4] [nvarchar](255) NULL
	,[ISO_Alpha3] [nvarchar](255) NULL
	) ON [PRIMARY]
GO


