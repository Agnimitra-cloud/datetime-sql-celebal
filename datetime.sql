USE AdventureWorks2019;
GO

CREATE OR ALTER PROCEDURE dbo.CalculateWorkingHours
    @StartDate DATETIME,
    @EndDate DATETIME,
    @DailyStartTime TIME = '08:00:00',
    @DailyEndTime TIME = '17:00:00',
    @LunchBreakHours DECIMAL(5,2) = 1.0
AS
BEGIN
    SET NOCOUNT ON;

    -- Input validations
    IF @StartDate > @EndDate
    BEGIN
        SELECT 0.0 AS TotalWorkingHours, 'Start date must be before end date' AS Message;
        RETURN;
    END;

    IF @DailyStartTime >= @DailyEndTime
    BEGIN
        SELECT 0.0 AS TotalWorkingHours, 'Start time must be earlier than end time' AS Message;
        RETURN;
    END;

    DECLARE @TotalHours DECIMAL(10,2) = 0.0;
    DECLARE @CurrentDate DATETIME = @StartDate;

    -- Create temporary table
    CREATE TABLE #WorkingDays (
        Date DATE,
        WorkingHours DECIMAL(5,2)
    );

    -- Process each day
    WHILE @CurrentDate <= @EndDate
    BEGIN
        DECLARE @DayOfWeek INT = DATEPART(WEEKDAY, @CurrentDate);
        DECLARE @IsWeekend BIT = 0;
        DECLARE @IsNonWorkingSaturday BIT = 0;

        -- Detect Sunday
        IF @DayOfWeek = 1
            SET @IsWeekend = 1;

        -- Check if it's a Saturday
        IF @DayOfWeek = 7
        BEGIN
            DECLARE @FirstDayOfMonth DATE = DATEFROMPARTS(YEAR(@CurrentDate), MONTH(@CurrentDate), 1);
            DECLARE @SaturdayCounter INT = 0;
            DECLARE @CheckDate DATE = @FirstDayOfMonth;

            WHILE MONTH(@CheckDate) = MONTH(@CurrentDate)
            BEGIN
                IF DATEPART(WEEKDAY, @CheckDate) = 7 -- Saturday
                BEGIN
                    SET @SaturdayCounter += 1;
                    IF @CheckDate = CAST(@CurrentDate AS DATE)
                        BREAK;
                END;
                SET @CheckDate = DATEADD(DAY, 1, @CheckDate);
            END;

            IF @SaturdayCounter > 2 -- 3rd, 4th, etc.
                SET @IsNonWorkingSaturday = 1;
        END;

        -- Skip non-working days
        IF @IsWeekend = 0 AND @IsNonWorkingSaturday = 0
        BEGIN
            DECLARE @DayStart DATETIME;
            DECLARE @DayEnd DATETIME;

            -- Determine working window for the day
            SET @DayStart = DATETIMEFROMPARTS(
                YEAR(@CurrentDate), MONTH(@CurrentDate), DAY(@CurrentDate),
                DATEPART(HOUR, @DailyStartTime), DATEPART(MINUTE, @DailyStartTime),
                DATEPART(SECOND, @DailyStartTime), 0
            );

            SET @DayEnd = DATETIMEFROMPARTS(
                YEAR(@CurrentDate), MONTH(@CurrentDate), DAY(@CurrentDate),
                DATEPART(HOUR, @DailyEndTime), DATEPART(MINUTE, @DailyEndTime),
                DATEPART(SECOND, @DailyEndTime), 0
            );

            -- Adjust if first or last day
            IF CAST(@CurrentDate AS DATE) = CAST(@StartDate AS DATE)
                SET @DayStart = IIF(@StartDate > @DayStart, @StartDate, @DayStart);

            IF CAST(@CurrentDate AS DATE) = CAST(@EndDate AS DATE)
                SET @DayEnd = IIF(@EndDate < @DayEnd, @EndDate, @DayEnd);

            -- Calculate hours
            DECLARE @HoursForDay DECIMAL(5,2) = DATEDIFF(MINUTE, @DayStart, @DayEnd) / 60.0;

            IF @HoursForDay >= 6.0
                SET @HoursForDay -= @LunchBreakHours;

            IF @HoursForDay > 0
            BEGIN
                INSERT INTO #WorkingDays (Date, WorkingHours)
                VALUES (CAST(@CurrentDate AS DATE), @HoursForDay);

                SET @TotalHours += @HoursForDay;
            END;
        END;

        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END;

    -- Final output
    SELECT 
        @TotalHours AS TotalWorkingHours,
        @StartDate AS StartDate,
        @EndDate AS EndDate;

    -- Optional breakdown
    SELECT 
        Date,
        WorkingHours,
        DATENAME(WEEKDAY, Date) AS DayName,
        CASE 
            WHEN DATEPART(WEEKDAY, Date) = 7 THEN 
                CASE 
                    WHEN DAY(Date) BETWEEN 1 AND 7 THEN '1st Week Saturday'
                    WHEN DAY(Date) BETWEEN 8 AND 14 THEN '2nd Week Saturday'
                    ELSE NULL
                END
            ELSE NULL
        END AS SpecialDayType
    FROM #WorkingDays
    ORDER BY Date;

    DROP TABLE #WorkingDays;
END;
GO

EXEC dbo.CalculateWorkingHours 
    @StartDate = '2025-06-01 09:30:00',
    @EndDate = '2025-06-10 16:30:00';
