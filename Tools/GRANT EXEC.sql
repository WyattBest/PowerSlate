USE [Campus6]
GRANT EXEC ON [custom].[PS_selISIR] TO PowerSlate
GRANT EXEC ON [custom].[PS_updDemographics] TO PowerSlate
GRANT EXEC ON [custom].[PS_updAcademicAppInfo] TO PowerSlate
GRANT EXEC ON [custom].[PS_updAcademicKey] TO PowerSlate
GRANT EXEC ON [custom].[PS_updAction] to PowerSlate
GRANT EXEC ON [custom].[PS_selProfile] to PowerSlate
GRANT EXEC ON [custom].[PS_selRAStatus] to PowerSlate
GRANT EXEC ON [custom].[PS_updSMSOptIn] to PowerSlate
GRANT EXEC ON [custom].[PS_selPFChecklist] to PowerSlate
GRANT EXEC ON [custom].[PS_insNote] to PowerSlate
GRANT EXEC ON [custom].[PS_updUserDefined] to PowerSlate
GRANT EXEC ON [custom].[PS_updEducation] to PowerSlate
GRANT EXEC ON [custom].[PS_updTestscore] to PowerSlate
GRANT EXEC ON [custom].[PS_updProgramOfStudy] to PowerSlate
GRANT EXEC ON [custom].[PS_selActions] to PowerSlate
GRANT EXEC ON [custom].[PS_delAction] to PowerSlate
GRANT EXEC ON [custom].[PS_selActionDefinition] to PowerSlate
GRANT SELECT, UPDATE, VIEW DEFINITION ON [USERDEFINEDIND]  to PowerSlate
GRANT EXEC ON [custom].[PS_selPersonDuplicate] to PowerSlate
GRANT EXEC ON [custom].[PS_updApplicationFormSetting] to PowerSlate
GRANT EXEC ON [custom].[PS_updStop] to PowerSlate
GRANT EXEC ON [custom].[PS_selPFAwardsXML] to PowerSlate

USE [PowerCampusMapper]
GRANT INSERT ON PowerSlate_AppStatus_Log TO PowerSlate
