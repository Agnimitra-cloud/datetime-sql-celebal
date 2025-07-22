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
    SET DATEFIRST 7; -- Sunday = 1

  
    IF @StartDate > @EndDate OR @DailyStartTime >= @DailyEndTime
    BEGIN
        SELECT 0.0 AS TotalWorkingHours, 'Invalid input dates or times' AS Message;
        RETURN;
    END;

    DECLARE @TotalHours DECIMAL(10,2) = 0.0;
    DECLARE @CurrentDate DATE = CAST(@StartDate AS DATE);

    -- Loop 
    WHILE @CurrentDate <= CAST(@EndDate AS DATE)
    BEGIN
        DECLARE @WeekDay INT = DATEPART(WEEKDAY, @CurrentDate);

        -- Skip Sunday
        IF @WeekDay <> 1
        BEGIN
            DECLARE @IsThirdSaturday BIT = 0;

            -- Check if Saturday and 3rd or later
            IF @WeekDay = 7
            BEGIN
                DECLARE @SatCount INT = 0;
                DECLARE @D DATE = DATEFROMPARTS(YEAR(@CurrentDate), MONTH(@CurrentDate), 1);

                WHILE @D <= @CurrentDate
                BEGIN
                    IF DATEPART(WEEKDAY, @D) = 7
                        SET @SatCount += 1;

                    SET @D = DATEADD(DAY, 1, @D);
                END;

                IF @SatCount > 2
                    SET @IsThirdSaturday = 1;
            END;

            -- Proceed if not 3rd+ Saturday
            IF NOT (@WeekDay = 7 AND @IsThirdSaturday = 1)
            BEGIN
                DECLARE @StartDT DATETIME = CAST(@CurrentDate AS DATETIME) + CAST(@DailyStartTime AS DATETIME);
                DECLARE @EndDT DATETIME = CAST(@CurrentDate AS DATETIME) + CAST(@DailyEndTime AS DATETIME);

                -- Adjust on first/last date
                IF @CurrentDate = CAST(@StartDate AS DATE) AND @StartDate > @StartDT
                    SET @StartDT = @StartDate;

                IF @CurrentDate = CAST(@EndDate AS DATE) AND @EndDate < @EndDT
                    SET @EndDT = @EndDate;

                DECLARE @Hours DECIMAL(5,2) = DATEDIFF(MINUTE, @StartDT, @EndDT) / 60.0;

                IF @Hours >= 6.0
                    SET @Hours -= @LunchBreakHours;

                IF @Hours > 0
                    SET @TotalHours += @Hours;
            END;
        END;

        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END;

    SELECT @TotalHours AS TotalWorkingHours, @StartDate AS StartDate, @EndDate AS EndDate;
END;
GO
EXEC dbo.CalculateWorkingHours 
    @StartDate = '2025-06-01 09:30:00',
    @EndDate = '2025-06-10 16:30:00';
