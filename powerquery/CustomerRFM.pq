// RetailPulse | CustomerRFM  (one row per customer with R, F, M scores and segment)
// Relationship: CustomerRFM[customer_key] 1:1 DimCustomer[customer_key]
let
    Source   = Csv.Document(File.Contents(DataFolder & "customer_rfm.csv"),
                            [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
                   {"customer_key", Int64.Type}, {"last_order_date", type date},
                   {"recency_days", Int64.Type}, {"frequency", Int64.Type},
                   {"monetary", Currency.Type}, {"r_score", Int64.Type},
                   {"f_score", Int64.Type}, {"m_score", Int64.Type},
                   {"rfm_code", type text}, {"segment", type text}})
in
    Typed
