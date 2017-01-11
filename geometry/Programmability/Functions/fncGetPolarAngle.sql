CREATE FUNCTION [geometry].[fncGetPolarAngle]
(
	@anchorPointX AS DECIMAL(38,24),
	@anchorPointY AS DECIMAL(38,24),
	@comparePointX AS DECIMAL(38,24),
	@comparePointY AS DECIMAL(38,24)
)
RETURNS DECIMAL(38,24)
AS
BEGIN
	DECLARE @RADIAN DECIMAL(38,24) = 57.295779513082;
	DECLARE @degrees DECIMAL(38,24) = 360.000000000000;
	DECLARE @deltaX DECIMAL(38,24)
		, @deltaY DECIMAL(38,24)
		, @angle DECIMAL(38,24);

	(SELECT @deltaX = @comparePointX - @anchorPointX);
	(SELECT @deltaY = @comparePointY - @anchorPointY);
        
	IF @deltaX = 0 AND @deltaY = 0
		BEGIN
			RETURN 0;
		END

	SELECT @angle = ATN2(@deltaY, @deltaX) * @RADIAN

	IF @angle >= 0
		BEGIN
			SELECT @angle = @angle + @degrees;
		END
      
	RETURN @angle;
END
