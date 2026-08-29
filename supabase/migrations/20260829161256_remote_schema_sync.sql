drop extension if exists "pg_net";


  create table "public"."user_stats" (
    "user_id" uuid not null,
    "streak_days" integer not null default 0,
    "best_streak" integer not null default 0,
    "points" integer not null default 0,
    "updated_at" timestamp with time zone not null default now(),
    "last_streak_at" date
      );


alter table "public"."user_stats" enable row level security;

alter table "public"."profiles" add column "residential_area" text;

CREATE UNIQUE INDEX user_stats_pkey ON public.user_stats USING btree (user_id);

alter table "public"."user_stats" add constraint "user_stats_pkey" PRIMARY KEY using index "user_stats_pkey";

alter table "public"."profiles" add constraint "profiles_residential_area_check" CHECK (((residential_area IS NULL) OR (residential_area = ANY (ARRAY['Ang Mo Kio'::text, 'Bedok'::text, 'Bishan'::text, 'Bukit Batok'::text, 'Bukit Merah'::text, 'Bukit Panjang'::text, 'Bukit Timah'::text, 'Central Area'::text, 'Choa Chu Kang'::text, 'Clementi'::text, 'Geylang'::text, 'Hougang'::text, 'Jurong East'::text, 'Jurong West'::text, 'Kallang/Whampoa'::text, 'Marine Parade'::text, 'Pasir Ris'::text, 'Punggol'::text, 'Queenstown'::text, 'Sembawang'::text, 'Sengkang'::text, 'Serangoon'::text, 'Tampines'::text, 'Tanglin'::text, 'Toa Payoh'::text, 'Woodlands'::text, 'Yishun'::text, 'Novena'::text])))) not valid;

alter table "public"."profiles" validate constraint "profiles_residential_area_check";

alter table "public"."user_stats" add constraint "user_stats_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."user_stats" validate constraint "user_stats_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.award_food_rescue_points(p_item_name text, p_points integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;
  if p_points <= 0 then
    raise exception 'points must be positive';
  end if;

  insert into public.points_ledger (user_id, source, source_id, points)
  values (v_user_id, 'food_rescue', p_item_name, p_points);

  update public.user_stats
    set points = points + p_points,
        updated_at = now()
    where user_id = v_user_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.award_quest_points(p_quest_id text, p_points integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;
  if p_points <= 0 then
    raise exception 'points must be positive';
  end if;

  insert into public.points_ledger (user_id, source, source_id, points)
  values (v_user_id, 'quest_claim', p_quest_id, p_points);

  update public.user_stats
    set points = points + p_points,
        updated_at = now()
    where user_id = v_user_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.bump_daily_streak()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_found boolean;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  update public.user_stats
    set streak_days = streak_days + 1,
        best_streak = greatest(best_streak, streak_days + 1),
        updated_at = now()
    where user_id = v_user_id
  returning true into v_found;

  if v_found is not true then
    raise exception 'no user_stats row for this user';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles (id, display_name, residential_area)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'residential_area'
  );

  insert into public.user_stats (user_id)
  values (new.id);

  return new;
end;
$function$
;

grant delete on table "public"."avoided_purchases" to "service_role";

grant insert on table "public"."avoided_purchases" to "service_role";

grant select on table "public"."avoided_purchases" to "service_role";

grant update on table "public"."avoided_purchases" to "service_role";

grant delete on table "public"."fridge_items" to "service_role";

grant insert on table "public"."fridge_items" to "service_role";

grant select on table "public"."fridge_items" to "service_role";

grant update on table "public"."fridge_items" to "service_role";

grant delete on table "public"."friend_requests" to "anon";

grant insert on table "public"."friend_requests" to "anon";

grant select on table "public"."friend_requests" to "anon";

grant update on table "public"."friend_requests" to "anon";

grant delete on table "public"."friend_requests" to "authenticated";

grant insert on table "public"."friend_requests" to "authenticated";

grant select on table "public"."friend_requests" to "authenticated";

grant update on table "public"."friend_requests" to "authenticated";

grant delete on table "public"."friend_requests" to "service_role";

grant insert on table "public"."friend_requests" to "service_role";

grant select on table "public"."friend_requests" to "service_role";

grant update on table "public"."friend_requests" to "service_role";

grant delete on table "public"."points_ledger" to "anon";

grant insert on table "public"."points_ledger" to "anon";

grant select on table "public"."points_ledger" to "anon";

grant update on table "public"."points_ledger" to "anon";

grant delete on table "public"."points_ledger" to "authenticated";

grant insert on table "public"."points_ledger" to "authenticated";

grant select on table "public"."points_ledger" to "authenticated";

grant update on table "public"."points_ledger" to "authenticated";

grant delete on table "public"."points_ledger" to "service_role";

grant insert on table "public"."points_ledger" to "service_role";

grant select on table "public"."points_ledger" to "service_role";

grant update on table "public"."points_ledger" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."quest_progress" to "anon";

grant insert on table "public"."quest_progress" to "anon";

grant select on table "public"."quest_progress" to "anon";

grant update on table "public"."quest_progress" to "anon";

grant delete on table "public"."quest_progress" to "authenticated";

grant insert on table "public"."quest_progress" to "authenticated";

grant select on table "public"."quest_progress" to "authenticated";

grant update on table "public"."quest_progress" to "authenticated";

grant delete on table "public"."quest_progress" to "service_role";

grant insert on table "public"."quest_progress" to "service_role";

grant select on table "public"."quest_progress" to "service_role";

grant update on table "public"."quest_progress" to "service_role";

grant delete on table "public"."quests" to "anon";

grant insert on table "public"."quests" to "anon";

grant select on table "public"."quests" to "anon";

grant update on table "public"."quests" to "anon";

grant delete on table "public"."quests" to "authenticated";

grant insert on table "public"."quests" to "authenticated";

grant select on table "public"."quests" to "authenticated";

grant update on table "public"."quests" to "authenticated";

grant delete on table "public"."quests" to "service_role";

grant insert on table "public"."quests" to "service_role";

grant select on table "public"."quests" to "service_role";

grant update on table "public"."quests" to "service_role";

grant delete on table "public"."user_stats" to "anon";

grant insert on table "public"."user_stats" to "anon";

grant references on table "public"."user_stats" to "anon";

grant select on table "public"."user_stats" to "anon";

grant trigger on table "public"."user_stats" to "anon";

grant truncate on table "public"."user_stats" to "anon";

grant update on table "public"."user_stats" to "anon";

grant delete on table "public"."user_stats" to "authenticated";

grant insert on table "public"."user_stats" to "authenticated";

grant references on table "public"."user_stats" to "authenticated";

grant select on table "public"."user_stats" to "authenticated";

grant trigger on table "public"."user_stats" to "authenticated";

grant truncate on table "public"."user_stats" to "authenticated";

grant update on table "public"."user_stats" to "authenticated";

grant delete on table "public"."user_stats" to "service_role";

grant insert on table "public"."user_stats" to "service_role";

grant references on table "public"."user_stats" to "service_role";

grant select on table "public"."user_stats" to "service_role";

grant trigger on table "public"."user_stats" to "service_role";

grant truncate on table "public"."user_stats" to "service_role";

grant update on table "public"."user_stats" to "service_role";


  create policy "Users can update their own profile"
  on "public"."profiles"
  as permissive
  for update
  to public
using ((auth.uid() = id));



  create policy "Users can view their own profile"
  on "public"."profiles"
  as permissive
  for select
  to public
using ((auth.uid() = id));



  create policy "Users can update their own stats"
  on "public"."user_stats"
  as permissive
  for update
  to public
using ((auth.uid() = user_id));



  create policy "Users can view their own stats"
  on "public"."user_stats"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));


CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


