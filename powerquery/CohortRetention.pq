// RetailPulse | CohortRetention  (cohort month x months since first purchase)
// Use in a Matrix: Rows = cohort_month, Columns = month_index, Values = retention_pct
// Apply conditional formatting (background color scale) for the heat map.
let
    Source   = Csv.Document(File.Contents(DataFolder & "cohort_retention.csv"),
                            [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
                   {"cohort_month", type date}, {"month_index", Int64.Type},
                   {"active_customers", Int64.Type}, {"cohort_size", Int64.Type},
                   {"retention_pct", type number}}),
    Label    = Table.AddColumn(Typed, "cohort_label",
                   each Date.ToText([cohort_month], "yyyy-MM"), type text)
in
    Label
