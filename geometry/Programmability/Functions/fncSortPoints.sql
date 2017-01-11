CREATE FUNCTION [geometry].[fncSortPoints]
(
	@points AS [geometry].[Point] READONLY,
	@anchorPointX AS DECIMAL(38,24),
	@anchorPointY AS DECIMAL(38,24)
)
RETURNS @sortedPoints TABLE (
	x DECIMAL(38,24) NOT NULL,
	y DECIMAL(38,24) NOT NULL,
	angle DECIMAL(38,24) NOT NULL
)
AS
BEGIN
	INSERT INTO @sortedPoints
	SELECT TOP 1000000 x, y, AngleToAnchor FROM 
		(
			SELECT  x, y, geometry.fncGetPolarAngle(@anchorPointX, @anchorPointY, x, y) AS AngleToAnchor
			FROM @points
		) as src
	ORDER BY src.AngleToAnchor ASC

	RETURN;
END
