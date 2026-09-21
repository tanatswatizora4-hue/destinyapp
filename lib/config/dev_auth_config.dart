/// DEV ONLY — UI redesign preview flag.
///
/// When `true`, protected-tab prompts stay as snackbars so designers can browse
/// the shell without signing in.
///
/// When `false` (live Auth QA / production-like):
/// - Home/Tours/Stays/Vehicles/Flights/Contact stay publicly browsable
/// - Protected account actions open the real Supabase LoginScreen
/// - Commerce and staff APIs still require a real access token either way
///
/// This flag never bypasses backend authorization.
const bool devBypassAuth = false;
