USE Campus6

SELECT LONG_DESC
	,CODE_VALUE_KEY
	,'<row RCCodeValue="' + CODE_VALUE_KEY + '" RCDesc="' + MEDIUM_DESC + '" PCCodeValue="' + CODE_VALUE_KEY + '" PCDesc="' + LONG_DESC + '" />' [xml]
FROM CODE_LANGUAGE
WHERE 1 = 1
	AND [STATUS] = 'A'
