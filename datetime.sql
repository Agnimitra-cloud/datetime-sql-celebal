CREATE PROCEDURE GetWorkingHours
    @StartDate DATETIME,
    @EndDate DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- Temp table to store date and exclusion status
    DECLARE @DateList TABLE (
        WorkDate DATETIME,
        IsExcluded BIT
    );

    DECLARE @CurrDate DATETIME = CAST(@StartDate AS DATE);

    WHILE @CurrDate <= @EndDate
    BEGIN
        DECLARE @IsExcluded BIT = 0;

        -- Check if it's Sunday
        IF DATENAME(WEEKDAY, @CurrDate) = 'Sunday'
            SET @IsExcluded = 1;

        -- Check for 1st and 2nd Saturdays
        IF DATENAME(WEEKDAY, @CurrDate) = 'Saturday'
        BEGIN
            DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@CurrDate), MONTH(@CurrDate), 1);
            DECLARE @Saturdays TABLE (SatDate DATE);
            DECLARE @DayCursor DATE = @MonthStart;

            WHILE MONTH(@DayCursor) = MONTH(@CurrDate)
            BEGIN
                IF DATENAME(WEEKDAY, @DayCursor) = 'Saturday'
                    INSERT INTO @Saturdays VALUES (@DayCursor);
                SET @DayCursor = DATEADD(DAY, 1, @DayCursor);
            END

            IF EXISTS (
                SELECT 1 FROM (
                    SELECT TOP 2 ROW_NUMBER() OVER (ORDER BY SatDate) AS RowNum, SatDate
                    FROM @Saturdays
                ) AS SatCheck
                WHERE SatDate = @CurrDate
            )
                SET @IsExcluded = 1;
        END

        -- Do NOT exclude if it's StartDate or EndDate
        IF CAST(@CurrDate AS DATE) = CAST(@StartDate AS DATE)
            OR CAST(@CurrDate AS DATE) = CAST(@EndDate AS DATE)
        BEGIN
            SET @IsExcluded = 0;
        END

        INSERT INTO @DateList (WorkDate, IsExcluded)
        VALUES (@CurrDate
