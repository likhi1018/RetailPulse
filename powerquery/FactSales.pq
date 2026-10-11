// RetailPulse | FactSales  (grain: one row per order item, delivered orders)
let
    Source   = Csv.Document(File.Contents(DataFolder & "fact_sales.csv"),
                            [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
                   {"order_id", type text}, {"order_item_id", Int64.Type},
                   {"date_key", Int64.Type}, {"customer_key", Int64.Type},
                   {"product_key", Int64.Type}, {"seller_key", Int64.Type},
                   {"price", Currency.Type}, {"freight_value", Currency.Type},
                   {"gross_item_value", Currency.Type}})
in
    Typed
