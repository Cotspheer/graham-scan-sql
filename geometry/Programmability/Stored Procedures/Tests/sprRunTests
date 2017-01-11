CREATE PROCEDURE [geometry].[sprRunTests]
AS
BEGIN

	DECLARE @Valid BIT = 1;
	
	EXEC [geometry].[sprTestPolarAngle] @Valid = @Valid OUTPUT
	EXEC [geometry].[sprTestSortPoints] @Valid = @Valid OUTPUT
	EXEC [geometry].[sprTestConvexHull] @Valid = @Valid OUTPUT

	SELECT @Valid
END
