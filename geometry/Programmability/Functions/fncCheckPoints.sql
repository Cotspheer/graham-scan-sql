CREATE FUNCTION [geometry].[fncCheckPoints]
(
	@point_1 AS [geometry].[Point] READONLY,
	@point_2 AS [geometry].[Point] READONLY,
	@point_3 AS [geometry].[Point] READONLY
)
RETURNS BIT
AS
BEGIN

	DECLARE @p1x DECIMAL(38,24) = (SELECT x FROM @point_1);
	DECLARE @p1y DECIMAL(38,24) = (SELECT y FROM @point_1);
	DECLARE @p2x DECIMAL(38,24) = (SELECT x FROM @point_2);
	DECLARE @p2y DECIMAL(38,24) = (SELECT y FROM @point_2);
	DECLARE @p3x DECIMAL(38,24) = (SELECT x FROM @point_3);
	DECLARE @p3y DECIMAL(38,24) = (SELECT y FROM @point_3);

	DECLARE @difAngle DECIMAL(38,24) = 0;
	DECLARE @cwAngle DECIMAL(38,24) = (SELECT [geometry].fncGetPolarAngle(@p1x, @p1y, @p2x, @p2y));
	DECLARE @ccAngle DECIMAL(38,24) = (SELECT [geometry].fncGetPolarAngle(@p1x, @p1y, @p3x, @p3y));

	IF @cwAngle > @ccAngle
		BEGIN
			SET @difAngle = @cwAngle - @ccAngle;

			IF (@difAngle > 180)
				BEGIN
					RETURN 0;
				END

			RETURN 1;
		END
	ELSE IF (@cwAngle < @ccAngle)
		BEGIN
			SET @difAngle = @ccAngle - @cwAngle;

			IF (@difAngle > 180)
				BEGIN
					RETURN 1;
				END

			RETURN 0;
		END

	RETURN 1;
END
