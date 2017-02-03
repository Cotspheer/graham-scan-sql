CREATE FUNCTION [geometry].[fncGetPolygon]
()
RETURNS NVARCHAR(MAX)
AS
BEGIN
	DECLARE @points AS [geometry].[Point]

  -- fncParseJson => https://www.simple-talk.com/sql/t-sql-programming/consuming-json-strings-in-sql-server/ | Phil Factor
	INSERT INTO @points
		(x, y)
	SELECT 
		(SELECT TOP 1
			CAST(StringValue AS DECIMAL(38,24))
		FROM core.fncParseJson(st.GeoJSON)
		WHERE SequenceNo = 1
				AND ValueType = 'real') AS x
		,(SELECT TOP 1
			CAST(StringValue AS DECIMAL(38,24))
		FROM core.fncParseJson(st.GeoJSON)
		WHERE SequenceNo = 2
				AND ValueType = 'real') AS y
	FROM work.SourceTable st

	DECLARE @hull TABLE (
		RowIndex INT PRIMARY KEY, -- force sql to preserve the row order!
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL,
		angle DECIMAL(38,24) NOT NULL
	)	

	INSERT INTO @hull
		(RowIndex, x, y, angle)
	SELECT RowIndex, x, y, angle FROM [geometry].[fncGetConvexHull](@points)

	DECLARE @hullCount INT = (SELECT COUNT(1) FROM @hull);
	DECLARE @geoJson NVARCHAR(MAX) = '';
	DECLARE @array NVARCHAR(MAX) = '';

	IF @hullCount = 1
		BEGIN
			SET @geoJson = '{"type":"Point","coordinates": ['

			SELECT TOP 1 @array = @array + '' + CAST(x AS NVARCHAR(100)) + ',' + CAST(y AS NVARCHAR(100)) + '' FROM @hull;

			SET @array = LEFT(LTRIM(RTRIM(@array)), NULLIF(LEN(@array)-1,-1))

			SET @geoJson = @geoJson + @array;
			
			SET @geoJson = @geoJson + ']}'
		END
	ELSE IF @hullCount = 2
		BEGIN
			SET @geoJson = '{"type":"LineString","coordinates": ['

			SELECT @array = @array + '[' + CAST(x AS NVARCHAR(100)) + ',' + CAST(y AS NVARCHAR(100)) + '],' FROM @hull;

			SET @array = LEFT(LTRIM(RTRIM(@array)), NULLIF(LEN(@array)-1,-1))

			SET @geoJson = @geoJson + @array;
			
			SET @geoJson = @geoJson + ']}'
		END
	ELSE -- 3+
		BEGIN
			SET @geoJson = '{"type":"Polygon","coordinates": [['

			SELECT @array = @array + '[' + CAST(x AS NVARCHAR(100)) + ',' + CAST(y AS NVARCHAR(100)) + '],' FROM @hull;

			SET @array = LEFT(LTRIM(RTRIM(@array)), NULLIF(LEN(@array)-1,-1))

			SET @geoJson = @geoJson + @array;
			
			SET @geoJson = @geoJson + ']]}'
		END
	RETURN @geoJson;
END
