// RetailPulse | DimDate - built entirely in Power Query (no CSV needed).
// After loading: Table tools > Mark as date table > column "Date".
// Sort "Month" by "MonthNum" and "YearMonth" by "DateKey".
let
    StartDate = #date(2016, 9, 1),
    EndDate   = #date(2018, 10, 31),
    Dates     = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
    ToTable   = Table.FromList(Dates, Splitter.SplitByNothing(), {"Date"}),
    Typed     = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),
    AddKey    = Table.AddColumn(Typed,   "DateKey",
                    each Date.Year([Date]) * 10000 + Date.Month([Date]) * 100 + Date.Day([Date]), Int64.Type),
    AddYear   = Table.AddColumn(AddKey,  "Year",      each Date.Year([Date]), Int64.Type),
    AddQtr    = Table.AddColumn(AddYear, "Quarter",   each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddMNum   = Table.AddColumn(AddQtr,  "MonthNum",  each Date.Month([Date]), Int64.Type),
    AddMonth  = Table.AddColumn(AddMNum, "Month",     each Date.ToText([Date], "MMM"), type text),
    AddYM     = Table.AddColumn(AddMonth,"YearMonth", each Date.ToText([Date], "yyyy-MM"), type text),
    AddMStart = Table.AddColumn(AddYM,   "MonthStart", each Date.StartOfMonth([Date]), type date),
    AddWDay   = Table.AddColumn(AddMStart, "Weekday", each Date.ToText([Date], "ddd"), type text),
    AddWNum   = Table.AddColumn(AddWDay, "WeekdayNum", each Date.DayOfWeek([Date], Day.Monday) + 1, Int64.Type),
    // Flag used to hide the sparse edge months from trend visuals
    AddFull   = Table.AddColumn(AddWNum, "IsCompleteMonth",
                    each [MonthStart] >= #date(2017, 1, 1) and [MonthStart] <= #date(2018, 8, 1), type logical)
in
    AddFull
