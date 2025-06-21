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
    
    -- Validate input dates
    IF @StartDate > @EndDate
    BEGIN
        SELECT 0.0 AS TotalWorkingHours, 
               'Start date must be before end date' AS Message;
        RETURN;
    END
    
    DECLARE @TotalHours DECIMAL(10,2) = 0.0;
    DECLARE @CurrentDate DATETIME = @StartDate;
    
    -- Temporary table to store working days
    CREATE TABLE #WorkingDays (
        Date DATE,
        WorkingHours DECIMAL(5,2)
    );
    
    -- Process each day in the date range
    WHILE @CurrentDate <= @EndDate
    BEGIN
        DECLARE @DayOfWeek INT = DATEPART(WEEKDAY, @CurrentDate);
        DECLARE @DayOfMonth INT = DAY(@CurrentDate);
        DECLARE @FirstDayOfMonth DATE = DATEFROMPARTS(YEAR(@CurrentDate), MONTH(@CurrentDate), 1);
        DECLARE @IsFirstOrSecondSaturday BIT = 0;
        
        -- Check if it's the 1st or 2nd Saturday of the month
        IF @DayOfWeek = 7 -- Saturday
        BEGIN
            DECLARE @FirstSaturday DATE = DATEADD(
                DAY, 
                (7 - DATEPART(WEEKDAY, @FirstDayOfMonth) + 1) % 7, 
                @FirstDayOfMonth
            );
            
            DECLARE @SecondSaturday DATE = DATEADD(DAY, 7, @FirstSaturday);
            
            IF CAST(@CurrentDate AS DATE) = @FirstSaturday 
               OR CAST(@CurrentDate AS DATE) = @SecondSaturday
                SET @IsFirstOrSecondSaturday = 1;
        END
        
        -- Calculate hours for working days
        IF @DayOfWeek <> 1 -- Not Sunday
           AND @IsFirstOrSecondSaturday = 0 -- Not 1st or 2nd Saturday
        BEGIN
            DECLARE @DayStart DATETIME;
            DECLARE @DayEnd DATETIME;
            DECLARE @HoursForDay DECIMAL(5,2);
            
            -- Handle start date (might be partial day)
            IF CAST(@CurrentDate AS DATE) = CAST(@StartDate AS DATE)
            BEGIN
                -- Use the later of start date/time or daily start time
                SET @DayStart = CASE 
                    WHEN CAST(@StartDate AS TIME) > @DailyStartTime THEN @StartDate
                    ELSE DATETIMEFROMPARTS(
                        YEAR(@CurrentDate), MONTH(@CurrentDate), DAY(@CurrentDate),
                        DATEPART(HOUR, @DailyStartTime), DATEPART(MINUTE, @DailyStartTime), 
                        DATEPART(SECOND, @DailyStartTime), 0
                    )
                END;
                
                -- End time is the earlier of end date/time or daily end time
                SET @DayEnd = CASE 
                    WHEN CAST(@EndDate AS DATE) = CAST(@StartDate AS DATE) 
                         AND CAST(@EndDate AS TIME) < @DailyEndTime THEN @EndDate
                    ELSE DATETIMEFROMPARTS(
                        YEAR(@CurrentDate), MONTH(@CurrentDate), DAY(@CurrentDate),
                        DATEPART(HOUR, @DailyEndTime), DATEPART(MINUTE, @DailyEndTime), 
                        DATEPART(SECOND, @DailyEndTime), 0
                    )
                END;
            END
            -- Handle end date (might be partial day)
            ELSE IF CAST(@CurrentDate AS DATE) = CAST(@EndDate AS DATE)
            BEGIN
                -- Start at daily start time
                SET @DayStart = DATETIMEFROMPARTS(
                    YEAR(@CurrentDate), MONTH(@CurrentDate), DAY(@CurrentDate),
                    DATEPART(HOUR, @DailyStartTime), DATEPART(MINUTE, @DailyStartTime), 
                    DATEPART(SECOND, @DailyStartTime), 0
                );
                
                -- End at the earlier of end time or daily end time
                SET @DayEnd = CASE 
                    WHEN CAST(@EndDate AS TIME) < @DailyEndTime THEN @EndDate
                    ELSE DATETIMEFROMPARTS(
                        YEAR(@CurrentDate), MONTH(@CurrentDate), DAY(@CurrentDate),
                        DATEPART(HOUR, @DailyEndTime), DATEPART(MINUTE, @DailyEndTime), 
                        DATEPART(SECOND, @DailyEndTime), 0
                    )
                END;
            END
            -- Full working days in between
            ELSE
            BEGIN
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
            END
            
            -- Calculate hours for the day (subtract lunch break if full day)
            SET @HoursForDay = DATEDIFF(MINUTE, @DayStart, @DayEnd)/60.0;
            
            -- Subtract lunch break if working at least 6 hours (full day)
            IF @HoursForDay >= 6.0
                SET @HoursForDay = @HoursForDay - @LunchBreakHours;
                
            -- Ensure non-negative hours
            IF @HoursForDay > 0
            BEGIN
                INSERT INTO #WorkingDays (Date, WorkingHours)
                VALUES (CAST(@CurrentDate AS DATE), @HoursForDay);
                
                SET @TotalHours = @TotalHours + @HoursForDay;
            END
        END
        
        -- Move to next day (without time component)
        SET @CurrentDate = DATEADD(DAY, 1, CAST(@CurrentDate AS DATE));
    END
    
    -- Return results
    SELECT 
        @TotalHours AS TotalWorkingHours,
        @StartDate AS StartDate,
        @EndDate AS EndDate;
    
    -- Optionally return daily breakdown
    SELECT 
        Date,
        WorkingHours,
        DATENAME(WEEKDAY, Date) AS DayName,
        CASE 
            WHEN DAY(Date) IN (1, 2, 3, 4, 5, 6, 7) 
                 AND DATEPART(WEEKDAY, Date) = 7 THEN '1st Week Saturday'
            WHEN DAY(Date) IN (8, 9, 10, 11, 12, 13, 14) 
                 AND DATEPART(WEEKDAY, Date) = 7 THEN '2nd Week Saturday'
            ELSE NULL
        END AS SpecialDayType
    FROM #WorkingDays
    ORDER BY Date;
    
    DROP TABLE #WorkingDays;
END
GO
