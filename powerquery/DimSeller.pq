// RetailPulse | DimSeller
let
    Source   = Csv.Document(File.Contents(DataFolder & "dim_seller.csv"),
                            [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
                   {"seller_key", Int64.Type}, {"seller_id", type text},
                   {"city", type text}, {"state_code", type text}, {"region", type text}}),
    // Short readable seller label for leaderboards, e.g. "Seller 0412"
    Label    = Table.AddColumn(Typed, "seller_label",
                   each "Seller " & Text.PadStart(Text.From([seller_key]), 4, "0"), type text)
in
    Label
