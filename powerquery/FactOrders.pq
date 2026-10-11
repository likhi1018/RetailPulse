// RetailPulse | FactOrders  (grain: one row per order, all statuses)
let
    Source   = Csv.Document(File.Contents(DataFolder & "fact_orders.csv"),
                            [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
                   {"order_id", type text}, {"date_key", Int64.Type}, {"customer_key", Int64.Type},
                   {"state_code", type text}, {"order_status", type text},
                   {"is_delivered", Int64.Type}, {"is_canceled", Int64.Type},
                   {"items_count", Int64.Type}, {"items_value", Currency.Type},
                   {"freight_value", Currency.Type}, {"payment_total", Currency.Type},
                   {"payment_count", Int64.Type}, {"max_installments", Int64.Type},
                   {"main_payment_type", type text}, {"delivery_days", type number},
                   {"delay_days", Int64.Type}, {"is_late", Int64.Type},
                   {"delay_bucket", type text}, {"review_score", Int64.Type}}),
    // Friendly labels for report visuals
    PaymentLabel = Table.TransformColumns(Typed, {{"main_payment_type",
                   each if _ = null then "Unknown"
                        else Text.Proper(Text.Replace(_, "_", " ")), type text}}),
    StatusLabel  = Table.TransformColumns(PaymentLabel, {{"order_status", Text.Proper, type text}}),
    // Text form of the score so it can be used as a chart axis / legend
    ReviewLabel  = Table.AddColumn(StatusLabel, "review_label",
                   each if [review_score] = null then "No review"
                        else Text.From([review_score]) & " star", type text)
in
    ReviewLabel
