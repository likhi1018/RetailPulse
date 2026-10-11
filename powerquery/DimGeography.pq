// RetailPulse | DimGeography  (27 Brazilian states -> 5 regions)
let
    Source   = Csv.Document(File.Contents(DataFolder & "dim_geography.csv"),
                            [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Typed    = Table.TransformColumnTypes(Promoted, {
                   {"state_code", type text}, {"state_name", type text}, {"region", type text}}),
    // Helps the Power BI map visual geocode correctly
    Country  = Table.AddColumn(Typed, "country", each "Brazil", type text),
    MapLabel = Table.AddColumn(Country, "map_location",
                   each [state_name] & ", Brazil", type text)
in
    MapLabel
