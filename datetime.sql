USE AdventureWorks;
GO

CREATE PROCEDURE dbo.GetWorkingHoursExcludingSundaysAndFirstTwoSaturdays
    @StartDate DATETIME,
    @EndDate DATETIME,
    @WorkingHours INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentDate DATETIME = @StartDate;
    DECLARE @TotalHours INT = 0;

    WHILE @CurrentDate < @EndDate
    BEGIN
        DECLARE @WeekDayName NVARCHAR(10) = DATENAME(WEEKDAY, @CurrentDate);

        IF @WeekDayName <> 'Sunday'
        BEGIN
            IF @WeekDayName = 'Saturday'
            BEGIN
                -- Calculate the first day of the current month
                DECLARE @MonthStart DATETIME = DATEFROMPARTS(YEAR(@CurrentDate), MONTH(@CurrentDate), 1);

                -- Count how many Saturdays have occurred this month up to the current date
                DECLARE @SaturdaysCount INT = (
                    SELECT COUNT(*) 
                    FROM (
                        SELECT TOP (DAY(@CurrentDate))
                            DATEADD(DAY, number, @MonthStart) AS Day
                        FROM master.dbo.spt_values
                        WHERE type = 'P' AND number < 31
                    ) AS Dates
                    WHERE DATENAME(WEEKDAY, Day) = 'Saturday'
                );

                -- Only count this hour if it's NOT 1st or 2nd Saturday
                IF @SaturdaysCount > 2
                    SET @TotalHours += 1;
            END
            ELSE
            BEGIN
                -- Not a Saturday or Sunday, count the hour
                SET @TotalHours += 1;
            END
        END

        -- Move to next hour
        SET @CurrentDate = DATEADD(HOUR, 1, @CurrentDate);
    END

    SET @WorkingHours = @TotalHours;
END
GO
