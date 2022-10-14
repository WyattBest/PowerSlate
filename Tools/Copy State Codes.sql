USE PowerCampusMapper

INSERT INTO Datatel_stateExtensionBase (
	Datatel_abbreviation
	,Datatel_name
	)
SELECT CODE_VALUE_KEY
	,LONG_DESC
FROM Campus6.dbo.CODE_STATE
WHERE [STATUS] = 'A'
