CREATE PROCEDURE [geometry].[sprTestPolarAngle]
	@Valid BIT OUTPUT
AS
BEGIN
	DECLARE @angle DECIMAL(38,24) = 0;
	DECLARE @assertAngle DECIMAL(38,24) = 434.054604099076741000000000;

	SELECT @angle = [geometry].[fncGetPolarAngle](11.1, 48.1, 11.3, 48.8);

	IF NOT (SELECT CHECKSUM_AGG(BINARY_CHECKSUM(@angle))) = (SELECT CHECKSUM_AGG(BINARY_CHECKSUM(@assertAngle)))
	BEGIN
		SET @Valid = 0;
	END
END