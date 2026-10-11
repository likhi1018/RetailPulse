// RetailPulse | Power Query parameter
// Create via Home > Manage Parameters > New Parameter
//   Name: DataFolder   Type: Text
//   Value: the full path to the repo's data/processed folder, ending with a slash
//   e.g. "C:\Users\you\RetailPulse\data\processed\"
// Every query below reads its CSV from this folder, so moving the
// project only means changing this one value.

"C:\RetailPulse\data\processed\" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]
