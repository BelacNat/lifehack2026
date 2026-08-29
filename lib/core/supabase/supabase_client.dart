import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared accessor for the Supabase client, initialized once in main.dart.
/// Import this instead of calling Supabase.instance.client directly, so
/// there's a single place to change if the initialization strategy changes.
SupabaseClient get supabase => Supabase.instance.client;