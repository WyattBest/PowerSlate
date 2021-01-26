USE PowerCampusMapper

SELECT D.*
	,LONG_DESC
	,CODE_VALUE_KEY
	,ISO3166_CODE
	,'<row RCCodeValue="' + Datatel_abbreviation + '" RCDesc="' + Datatel_name + '" PCCodeValue="' + CODE_VALUE_KEY + '" PCDesc="' + LONG_DESC + '" />' [xml]
FROM Datatel_countryExtensionBase D
LEFT JOIN Campus6.dbo.code_country CC
	ON CC.ISO3166_CODE = Datatel_abbreviation
		OR LONG_DESC = Datatel_name;

--Duplicates check
SELECT ISO3166_CODE
	,*
FROM Campus6.dbo.CODE_COUNTRY
WHERE ISO3166_CODE IN (
		SELECT ISO3166_CODE
		FROM Campus6.dbo.CODE_COUNTRY
		WHERE ISO3166_CODE IS NOT NULL
		GROUP BY ISO3166_CODE
		HAVING count(*) > 1
		)

--Check for a variety of problems
SELECT CODE_VALUE_KEY
	,ISO3166_CODE
	,MEDIUM_DESC
	,LONG_DESC
	,Datatel_abbreviation [Slate Code]
	,DATATEL_NAME [Slate Name]
	,CASE 
		WHEN ISO3166_CODE IS NULL
			THEN 'Code Missing'
		WHEN ISO3166_CODE <> Datatel_abbreviation
			THEN 'Code Mismatch'
		WHEN LONG_DESC <> Datatel_name
			THEN 'Name Mismatch/Misspelled'
		ELSE 'No Match'
		END AS [Reason]
FROM Campus6.dbo.CODE_COUNTRY
LEFT JOIN Datatel_countryExtensionBase
	ON ISO3166_CODE = Datatel_abbreviation
		OR LONG_DESC = Datatel_name
		OR medium_desc = datatel_name
WHERE 1 = 1
	AND ISO3166_CODE <> Datatel_abbreviation
	OR ISO3166_CODE IS NULL
	OR LONG_DESC <> Datatel_name
