// RetailPulse | DimCustomer  (one row per real customer, customer_unique_id)
let
    Source   = Csv.Document(File.Contents(DataFolder & "dim_customer.csv"),
                            [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
                   {"customer_key", Int64.Type}, {"customer_unique_id", type text},
                   {"city", type text}, {"state_code", type text}, {"region", type text},
                   {"first_order_date", type date}, {"last_order_date", type date},
                   {"cohort_month", type date}, {"delivered_orders", Int64.Type},
                   {"customer_type", type text}}),
    // Long hash id is not needed for reporting; dropping it shrinks the model
    Removed  = Table.RemoveColumns(Typed, {"customer_unique_id"})
in
    Removed
