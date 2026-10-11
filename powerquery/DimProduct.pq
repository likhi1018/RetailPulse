// RetailPulse | DimProduct  (one row per product, English category)
let
    Source   = Csv.Document(File.Contents(DataFolder & "dim_product.csv"),
                            [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
                   {"product_key", Int64.Type}, {"product_id", type text},
                   {"category_pt", type text}, {"category", type text},
                   {"product_weight_g", Int64.Type}, {"weight_class", type text},
                   {"product_photos_qty", Int64.Type}}),
    Removed  = Table.RemoveColumns(Typed, {"product_id", "category_pt"})
in
    Removed
