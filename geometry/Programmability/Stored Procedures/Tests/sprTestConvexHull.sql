CREATE PROCEDURE [geometry].[sprTestConvexHull]
	@Valid BIT OUTPUT
AS
BEGIN

	-----------------------------------------------------------------------------------
	DECLARE @assertHullPoints TABLE (
		RowIndex INT PRIMARY KEY, -- force sql to preserve the row order!
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL,
		angle DECIMAL(38,24) NOT NULL
	)

	INSERT INTO @assertHullPoints
		(RowIndex, x, y, angle)
	SELECT			1,	11.233300000000000000000000,             48.783300000000000000000000,             0.000000000000000000000000
	UNION SELECT	2,	11.300000000000000000000000,             48.800000000000000000000000,             374.056453618591947000000000
	UNION SELECT	3,	11.366700000000000000000000,             48.816700000000000000000000,             374.056453618591947000000000
	UNION SELECT	4,	11.416700000000000000000000,             48.833300000000000000000000,             375.249831651350535000000000
	UNION SELECT	5,	11.373385000000000000000000,             48.872829000000000000000000,             392.582842421694345000000000
	UNION SELECT	6,	11.216700000000000000000000,             49.000000000000000000000000,             454.380507874729673000000000
	UNION SELECT	7,	10.990565000000000000000000,             48.893175000000000000000000,             515.645918505548280000000000
	UNION SELECT	8,	11.006020000000000000000000,             48.869460000000000000000000,             519.238689373502040000000000
	UNION SELECT	9,	11.100000000000000000000000,             48.800000000000000000000000,             532.859113709804320000000000
	-----------------------------------------------------------------------------------


	-----------------------------------------------------------------------------------
	DECLARE @samplePoints TABLE (
		RowIndex INT IDENTITY(1,1) PRIMARY KEY, -- force sql to preserve the row order!
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL
	)

	INSERT INTO @samplePoints
		(x, y)
	SELECT 11.2333							, 48.7833	-- anchor point!
        UNION SELECT 11.3					, 48.8		
        UNION SELECT 11.3667				, 48.8167	
        UNION SELECT 11.4167				, 48.8333	
        UNION SELECT 11.3167				, 48.8167	
        UNION SELECT 11.373385				, 48.872829	
        UNION SELECT 11.3167				, 48.85		
        UNION SELECT 11.3					, 48.9167	
        UNION SELECT 11.2333				, 48.8		
        UNION SELECT 11.2167				, 49		
        UNION SELECT 11.2					, 48.95		
        UNION SELECT 11.2167				, 48.8333	
        UNION SELECT 11.198945				, 48.88636	
        UNION SELECT 11.184313				, 48.890609	
        UNION SELECT 11.1					, 48.9		
        UNION SELECT 11.0667				, 48.8667	
        UNION SELECT 10.990565				, 48.893175	
        UNION SELECT 11						, 48.8833	
        UNION SELECT 11.00602				, 48.86946	
        UNION SELECT 11.1					, 48.8
	-----------------------------------------------------------------------------------

	DECLARE @hullPoints TABLE (
		RowIndex INT PRIMARY KEY, -- force sql to preserve the row order!
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL,
		angle DECIMAL(38,24) NOT NULL
	)
	
	DECLARE @parameterPoints AS [geometry].[Point];

	INSERT INTO @parameterPoints
		SELECT TOP 1000000 x, y FROM @samplePoints

	-----------------------------------------------------------------------------------
	INSERT INTO @hullPoints
	SELECT TOP 1000000  RowIndex, x, y, angle FROM [geometry].[fncGetConvexHull](@parameterPoints) ORDER BY angle
	-----------------------------------------------------------------------------------

	IF NOT ((SELECT CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM @hullPoints) = (SELECT   CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM @assertHullPoints))
	BEGIN
		SET @Valid = 0
	END
END
