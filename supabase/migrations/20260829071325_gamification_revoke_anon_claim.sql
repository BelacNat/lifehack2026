-- Supabase grants EXECUTE to anon/authenticated by default on new
-- functions, independent of the earlier "revoke ... from public". Close
-- that off explicitly: only signed-in users may call this.
revoke execute on function public.claim_quest_reward(text) from anon;
