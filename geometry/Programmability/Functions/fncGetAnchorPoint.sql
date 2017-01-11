CREATE FUNCTION [geometry].[fncGetAnchorPoint]
(
	@points AS [geometry].[Point] READONLY
)
RETURNS @anchorPoint TABLE (
	RowIndex INT NOT NULL,
	x DECIMAL(38,24) NOT NULL,
	y DECIMAL(38,24) NOT NULL
)
AS
BEGIN
	
	DECLARE @x DECIMAL(38,24), 
		@y DECIMAL(38,24), 
		@index INT = NULL,
		@anchorX DECIMAL(38,24) = NULL, 
		@anchorY DECIMAL(38,24) = NULL,
		@anchorIndex INT = NULL;

	DECLARE crsPoint CURSOR FORWARD_ONLY FAST_FORWARD 
		FOR SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS IndexIndicator, x, y FROM @points
	OPEN crsPoint  
	FETCH NEXT FROM crsPoint
	INTO @index, @x, @y  
	WHILE @@FETCH_STATUS = 0  
	BEGIN

		IF (@anchorX IS NULL AND @anchorY IS NULL)
			OR (@anchorY > @y)
			OR (@anchorY = @y AND @anchorX > @x)
			BEGIN
				SET @anchorX = @x;
				SET @anchorY = @y;
				SET @anchorIndex = @index
			END
		FETCH NEXT FROM crsPoint   
		INTO @index, @x, @y  
	END   
	CLOSE crsPoint;  
	DEALLOCATE crsPoint;

	INSERT INTO @anchorPoint
		SELECT @anchorIndex AS RowIndex, @anchorX AS x, @anchorY AS y;

	RETURN;
END
