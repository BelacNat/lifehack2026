import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase client accessor — import this rather than calling
/// `Supabase.instance.client` directly, so there's one place to change if
/// the setup ever needs to.
SupabaseClient get supabase => Supabase.instance.client;
