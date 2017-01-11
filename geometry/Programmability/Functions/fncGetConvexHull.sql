/******************************************************************************
**  Description: SQL implementation of the graham-scan algorithm for creating a convex hull in O(N Log(N)) time.
**
**
**  Return: Sorted convex hull of a given unsorted set of 2D points.
**
**  Author: T. Erni
**  Date: 10.01.2017
**
**
*******************************************************************************
**  Change History
*******************************************************************************
**  Date:      Author:         Description:
**  --------    --------------  -----------------------------------------------
******************************************************************************/
CREATE FUNCTION [geometry].[fncGetConvexHull]
(
	@Points AS [geometry].[Point] READONLY
)
RETURNS @outputHullPoints TABLE (
	RowIndex INT PRIMARY KEY, -- force sql to preserve the row order!
	x DECIMAL(38,24) NOT NULL,
	y DECIMAL(38,24) NOT NULL,
	angle DECIMAL(38,24) NOT NULL
)
AS
BEGIN

	-- working table
	DECLARE @hullPoints TABLE (
		RowIndex INT IDENTITY(1,1) PRIMARY KEY, -- force sql to preserve the row order!
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL,
		angle DECIMAL(38,24) NOT NULL
	)

	-- bypass readonly argument
	-- bypass parameter sniffing
	DECLARE @_points AS [geometry].[Point];

	INSERT INTO @_points
		SELECT TOP 1000000 x, y FROM @Points;

	-- remove unnecessary work and avoid errors later in the algorithm
	;WITH remove_duplicates AS(
	   SELECT 
			x, 
			y,
			RN = ROW_NUMBER()OVER(PARTITION BY x, y ORDER BY x)
	   FROM @_points
	)
	DELETE FROM remove_duplicates WHERE RN > 1;
	 
	 -- if there are less than 3 points, joining these points creates a correct hull.
	 -- so we return just those points.
	IF (SELECT COUNT(1) FROM @_points) < 2
		BEGIN
			INSERT INTO @outputHullPoints
				(RowIndex, x, y, angle)
			SELECT TOP 10 ROW_NUMBER() OVER(ORDER BY (SELECT 1)), x, y, 0 FROM @_points;

			RETURN;
		END

	-- a point where the algorithm starts to sort, "scan", the other points.
	-- the point depends on the input order, but it isn't essential which one we took. therefor no sort here!
	DECLARE 
			@anchorPoint AS [geometry].[Point]
			, @anchorPointIndex as INT
			, @anchorPointX AS DECIMAL(38,24)
			, @anchorPointY AS DECIMAL(38,24)
			;

	DECLARE @anchorOutput TABLE(
		RowIndex INT NOT NULL,
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL
	);

	-- calculate anchor-point
	INSERT INTO @anchorOutput
		SELECT RowIndex, x, y FROM [geometry].[fncGetAnchorPoint](@_points);

	-- save output
	INSERT INTO @anchorPoint
		SELECT TOP 1 x, y FROM @anchorOutput;

	SELECT TOP 1 @anchorPointX = x, @anchorPointY = y FROM @anchorPoint;

	SELECT TOP 1 @anchorPointIndex = RowIndex FROM @anchorOutput;

	-- anchor point gets removed from points to process
	-- we add it at the top at the end of the algorithm, when all work is done
	--**** SPLICE
	;WITH splice AS
	(
		SELECT TOP 1 * FROM (
			SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS IndexIndicator, x, y FROM @_points
		) src
		WHERE src.IndexIndicator = @anchorPointIndex
		ORDER BY src.IndexIndicator ASC
	)
	DELETE FROM splice;
	--**** SPLICE

	-- now we have to sort our points by their angle and their x value (counter clockwise scan, from left to right)
	DECLARE @sortedPoints TABLE (
		RowIndex INT IDENTITY(1,1) PRIMARY KEY, -- force sql to preserve the row order!
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL,
		angle DECIMAL(38,24) NOT NULL
	)

	-- sort points by their angle
	INSERT INTO @sortedPoints
		(x, y, angle)
	SELECT x, y, angle FROM [geometry].[fncSortPoints](@_points, @anchorPointX, @anchorPointY);

	-- update total length
	DECLARE @totalPoints AS INT = (SELECT COUNT(1) FROM @sortedPoints);

	-- if there are only 3 points (2 + anchorpoint) we return a correctly sorted point list. joining those would give a correct hull.
	IF @totalPoints = 2
		BEGIN
			--**** UNSHIFT
			INSERT INTO @outputHullPoints
				(RowIndex, x, y, angle)
			SELECT TOP 1000000
				ROW_NUMBER() OVER(ORDER BY (SELECT 1)) -- pristine id, represents sort order
				, src.x
				, src.y
				, src.angle
			FROM (
					SELECT @anchorPointX as x, @anchorPointY as y, 0 as angle
					UNION SELECT TOP 1000000 -- force sql to preserve the row order!
						x as x, y as y, angle as angle
					FROM @sortedPoints
				) as src
			ORDER BY src.angle; -- force sql to preserve the row order!
			--**** UNSHIFT

			RETURN;
		END

	-- init base set of 2 points. 
	-- Every iteration one is added and compared to the latest 2 in the set

	--**** SHIFT
	INSERT INTO @hullPoints
		(x, y, angle)
	SELECT TOP 2 x, y, angle FROM @sortedPoints

	;WITH spoints AS
	(
		SELECT TOP 2
			*
		FROM @sortedPoints
	)
	DELETE FROM spoints
	--****

	-- reference points for comparison
	DECLARE 
			@refPoint_1 AS [geometry].[Point]
			, @refPoint_2 AS [geometry].[Point]
			, @refPoint_3 AS [geometry].[Point]

	-- hullPoints.length
	DECLARE @hullPointsRowCount INT = 0;
	DECLARE @pointsLeftToProcessLength AS INT = 0;

	-- fail-safe break condition for the while loop to avoid never ending loops.
	DECLARE @failSafeSwitch BIT = 0;
	DECLARE @failSafeCounter INT = 0;
	DECLARE @maxCount INT = 10000;

	WHILE(((1 = 1) AND @failSafeSwitch = 0))
		BEGIN
			
			SET @failSafeCounter = @failSafeCounter + 1;
			
			IF @failSafeCounter >= @maxCount
				BEGIN
					SET @failSafeSwitch = 1;
				END

			-- take next point from the sorted list and add it to the output list
			--**** SHIFT
			INSERT INTO @hullPoints
				(x, y, angle)
			SELECT TOP 1 x, y, angle FROM @sortedPoints
			
			;WITH spoints AS
			(
				SELECT TOP 1
					*
				FROM @sortedPoints
			)
			DELETE FROM spoints
			--****

			-- points.length => update the count of the points which are left
			SET @pointsLeftToProcessLength = (SELECT COUNT(1) FROM @sortedPoints);

			-- hullPoints.length => update the current row count | array.length
			SET @hullPointsRowCount = (SELECT COUNT(1) FROM @hullPoints);

			-- clean previous selected points
			DELETE FROM @refPoint_1;
			DELETE FROM @refPoint_2;
			DELETE FROM @refPoint_3;

			-- select points based on theire index (hullPoints[hullPoints.length - 3])
			INSERT INTO @refPoint_1
				SELECT x, y FROM (
					SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS SortIndicator, x, y FROM @hullPoints
				) src
				ORDER BY src.SortIndicator ASC
				OFFSET (@hullPointsRowCount - 3) ROWS FETCH NEXT (1) ROWS ONLY; -- selects always the third last row

			INSERT INTO @refPoint_2
				SELECT x, y FROM (
					SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS SortIndicator, x, y FROM @hullPoints
				) src
				ORDER BY src.SortIndicator ASC
				OFFSET (@hullPointsRowCount - 2) ROWS FETCH NEXT (1) ROWS ONLY; -- selects always the second last row

			INSERT INTO @refPoint_3
				SELECT x, y FROM (
					SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS SortIndicator, x, y FROM @hullPoints
				) src
				ORDER BY src.SortIndicator ASC
				OFFSET (@hullPointsRowCount - 1) ROWS FETCH NEXT (1) ROWS ONLY; -- selects always the last row

			-- counter clockwise comparison. Removes points which are inside the convex hull
			IF (SELECT [geometry].fncCheckPoints(@refPoint_1, @refPoint_2, @refPoint_3)) = 1
				BEGIN
					--**** SPLICE
					;WITH splice AS
					(
						SELECT TOP 1 * FROM (
							SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS IndexIndicator, x, y FROM @hullPoints
						) src
						WHERE src.IndexIndicator = @hullPointsRowCount - 1
						ORDER BY src.IndexIndicator ASC
					)
					DELETE FROM splice;
					--**** SHIFT

					-- update length
					SET @hullPointsRowCount = (SELECT COUNT(1) FROM @hullPoints);
				END

			-- are there any points we didn't compare, if so run another round.
			IF @pointsLeftToProcessLength != 0 
				BEGIN
					CONTINUE;
				END

CREATE FUNCTION [geometry].[fncGetConvexHull]
(
	@Points AS [geometry].[Point] READONLY
)
RETURNS @outputHullPoints TABLE (
	RowIndex INT PRIMARY KEY, -- force sql to preserve the row order!
	x DECIMAL(38,24) NOT NULL,
	y DECIMAL(38,24) NOT NULL,
	angle DECIMAL(38,24) NOT NULL
)
AS
BEGIN

	-- working table
	DECLARE @hullPoints TABLE (
		RowIndex INT IDENTITY(1,1) PRIMARY KEY, -- force sql to preserve the row order!
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL,
		angle DECIMAL(38,24) NOT NULL
	)

	-- bypass readonly argument
	-- bypass parameter sniffing
	DECLARE @_points AS [geometry].[Point];

	INSERT INTO @_points
		SELECT TOP 1000000 x, y FROM @Points;

	-- remove unnecessary work and avoid errors later in the algorithm
	;WITH remove_duplicates AS(
	   SELECT 
			x, 
			y,
			RN = ROW_NUMBER()OVER(PARTITION BY x, y ORDER BY x)
	   FROM @_points
	)
	DELETE FROM remove_duplicates WHERE RN > 1;
	 
	 -- if there are less than 3 points, joining these points creates a correct hull.
	 -- so we return just those points.
	IF (SELECT COUNT(1) FROM @_points) <= 2
		BEGIN
			INSERT INTO @outputHullPoints
				(RowIndex, x, y, angle)
			SELECT TOP 10 ROW_NUMBER() OVER(ORDER BY (SELECT 1)), x, y, 0 FROM @_points;

			RETURN;
		END

	-- a point where the algorithm starts to sort, "scan", the other points.
	-- the point depends on the input order, but it isn't essential which one we took. therefor no sort here!
	DECLARE 
			@anchorPoint AS [geometry].[Point]
			, @anchorPointIndex as INT
			, @anchorPointX AS DECIMAL(38,24)
			, @anchorPointY AS DECIMAL(38,24)
			;

	DECLARE @anchorOutput TABLE(
		RowIndex INT NOT NULL,
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL
	);

	-- calculate anchor-point
	INSERT INTO @anchorOutput
		SELECT RowIndex, x, y FROM [geometry].[fncGetAnchorPoint](@_points);

	-- save output
	INSERT INTO @anchorPoint
		SELECT TOP 1 x, y FROM @anchorOutput;

	SELECT TOP 1 @anchorPointX = x, @anchorPointY = y FROM @anchorPoint;

	SELECT TOP 1 @anchorPointIndex = RowIndex FROM @anchorOutput;

	-- anchor point gets removed from points to process
	-- we add it at the top at the end of the algorithm, when all work is done
	--**** SPLICE
	;WITH splice AS
	(
		SELECT TOP 1 * FROM (
			SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS IndexIndicator, x, y FROM @_points
		) src
		WHERE src.IndexIndicator = @anchorPointIndex
		ORDER BY src.IndexIndicator ASC
	)
	DELETE FROM splice;
	--**** SPLICE

	-- now we have to sort our points by their angle and their x value (counter clockwise scan, from left to right)
	DECLARE @sortedPoints TABLE (
		RowIndex INT IDENTITY(1,1) PRIMARY KEY, -- force sql to preserve the row order!
		x DECIMAL(38,24) NOT NULL,
		y DECIMAL(38,24) NOT NULL,
		angle DECIMAL(38,24) NOT NULL
	)

	-- sort points by their angle
	INSERT INTO @sortedPoints
		(x, y, angle)
	SELECT x, y, angle FROM [geometry].[fncSortPoints](@_points, @anchorPointX, @anchorPointY);

	-- update total length
	DECLARE @totalPoints AS INT = (SELECT COUNT(1) FROM @sortedPoints);

	-- if there are only 3 points (2 + anchorpoint) we return a correctly sorted point list. joining those would give a correct hull.
	IF @totalPoints = 2
		BEGIN
			--**** UNSHIFT
			INSERT INTO @outputHullPoints
				(RowIndex, x, y, angle)
			SELECT TOP 1000000
				ROW_NUMBER() OVER(ORDER BY (SELECT 1)) -- pristine id, represents sort order
				, src.x
				, src.y
				, src.angle
			FROM (
					SELECT @anchorPointX as x, @anchorPointY as y, 0 as angle
					UNION SELECT TOP 1000000 -- force sql to preserve the row order!
						x as x, y as y, angle as angle
					FROM @sortedPoints
				) as src
			ORDER BY src.angle; -- force sql to preserve the row order!
			--**** UNSHIFT

			RETURN;
		END

	-- init base set of 2 points. 
	-- Every iteration one is added and compared to the latest 2 in the set

	--**** SHIFT
	INSERT INTO @hullPoints
		(x, y, angle)
	SELECT TOP 2 x, y, angle FROM @sortedPoints

	;WITH spoints AS
	(
		SELECT TOP 2
			*
		FROM @sortedPoints
	)
	DELETE FROM spoints
	--****

	-- reference points for comparison
	DECLARE 
			@refPoint_1 AS [geometry].[Point]
			, @refPoint_2 AS [geometry].[Point]
			, @refPoint_3 AS [geometry].[Point]

	-- hullPoints.length
	DECLARE @hullPointsRowCount INT = 0;
	DECLARE @pointsLeftToProcessLength AS INT = 0;

	-- fail-safe break condition for the while loop to avoid never ending loops.
	DECLARE @failSafeSwitch BIT = 0;
	DECLARE @failSafeCounter INT = 0;
	DECLARE @maxCount INT = 10000;

	WHILE(((1 = 1) AND @failSafeSwitch = 0))
		BEGIN
			
			SET @failSafeCounter = @failSafeCounter + 1;
			
			IF @failSafeCounter >= @maxCount
				BEGIN
					SET @failSafeSwitch = 1;
				END

			-- take next point from the sorted list and add it to the output list
			--**** SHIFT
			INSERT INTO @hullPoints
				(x, y, angle)
			SELECT TOP 1 x, y, angle FROM @sortedPoints
			
			;WITH spoints AS
			(
				SELECT TOP 1
					*
				FROM @sortedPoints
			)
			DELETE FROM spoints
			--****

			-- points.length => update the count of the points which are left
			SET @pointsLeftToProcessLength = (SELECT COUNT(1) FROM @sortedPoints);

			-- hullPoints.length => update the current row count | array.length
			SET @hullPointsRowCount = (SELECT COUNT(1) FROM @hullPoints);

			-- clean previous selected points
			DELETE FROM @refPoint_1;
			DELETE FROM @refPoint_2;
			DELETE FROM @refPoint_3;

			-- select points based on theire index (hullPoints[hullPoints.length - 3])
			INSERT INTO @refPoint_1
				SELECT x, y FROM (
					SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS SortIndicator, x, y FROM @hullPoints
				) src
				ORDER BY src.SortIndicator ASC
				OFFSET (@hullPointsRowCount - 3) ROWS FETCH NEXT (1) ROWS ONLY; -- selects always the third last row

			INSERT INTO @refPoint_2
				SELECT x, y FROM (
					SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS SortIndicator, x, y FROM @hullPoints
				) src
				ORDER BY src.SortIndicator ASC
				OFFSET (@hullPointsRowCount - 2) ROWS FETCH NEXT (1) ROWS ONLY; -- selects always the second last row

			INSERT INTO @refPoint_3
				SELECT x, y FROM (
					SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS SortIndicator, x, y FROM @hullPoints
				) src
				ORDER BY src.SortIndicator ASC
				OFFSET (@hullPointsRowCount - 1) ROWS FETCH NEXT (1) ROWS ONLY; -- selects always the last row

			-- counter clockwise comparison. Removes points which are inside the convex hull
			IF (SELECT [geometry].fncCheckPoints(@refPoint_1, @refPoint_2, @refPoint_3)) = 1
				BEGIN
					--**** SPLICE
					;WITH splice AS
					(
						SELECT TOP 1 * FROM (
							SELECT ROW_NUMBER() OVER(ORDER BY (SELECT 1)) AS IndexIndicator, x, y FROM @hullPoints
						) src
						WHERE src.IndexIndicator = @hullPointsRowCount - 1
						ORDER BY src.IndexIndicator ASC
					)
					DELETE FROM splice;
					--**** SHIFT

					-- update length
					SET @hullPointsRowCount = (SELECT COUNT(1) FROM @hullPoints);
				END

			-- are there any points we didn't compare, if so run another round.
			IF @pointsLeftToProcessLength != 0 
				BEGIN
					CONTINUE;
				END

			-- all current points are compared. Do we have any points we didn't take into account?
			-- if so we swap the points and make a new inital set
			IF @totalPoints != @hullPointsRowCount
				BEGIN
					
					DELETE FROM @sortedPoints;

					INSERT INTO @sortedPoints
						(x, y, angle)
					SELECT TOP 1000000 x, y, angle FROM @hullPoints ORDER BY angle;

					SET @pointsLeftToProcessLength = (SELECT COUNT(1) FROM @sortedPoints);
					SET @totalPoints = (SELECT COUNT(1) FROM @sortedPoints);

					DELETE FROM @hullPoints;

					-- init base set of 2 points. Every iteration one is added and compared to the latest 2 in the set
					--**** SHIFT
					INSERT INTO @hullPoints
						(x, y, angle)
					SELECT TOP 2 x, y, angle FROM @sortedPoints

					;WITH spoints AS
					(
						SELECT TOP 2
							*
						FROM @sortedPoints
					)
					DELETE FROM spoints
					--****

					-- update length
					SET @pointsLeftToProcessLength = (SELECT COUNT(1) FROM @sortedPoints);

					-- do another round to process the new set
					CONTINUE;
				END

			-- the anchor point shouldn't be present.
			-- we add it at the top
			IF NOT EXISTS (SELECT * FROM @hullPoints WHERE x = @anchorPointX AND y = @anchorPointY)
				BEGIN
					-- add anchor point to the top
					-- add points with a pristine id.
					--**** UNSHIFT
					INSERT INTO @outputHullPoints
						(RowIndex, x, y, angle)
					SELECT TOP 1000000
						ROW_NUMBER() OVER(ORDER BY (SELECT 1)) -- pristine id, represents sort order
						, src.x
						, src.y
						, src.angle
					FROM (
							SELECT @anchorPointX as x, @anchorPointY as y, 0 as angle
							UNION SELECT TOP 1000000 -- force sql to preserve the row order!
								x as x, y as y, angle as angle
							FROM @hullPoints
						) as src
					ORDER BY src.angle; -- force sql to preserve the row order!
					--**** UNSHIFT

					-- convex hull is generated, we are done!
					RETURN;
				END

			BREAK;
		END

	RETURN;
END
