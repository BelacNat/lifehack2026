-- Seeds the quest catalog with the 4 quests that were previously hardcoded
-- in lib/features/quests/data/mock_quests_data.dart.

insert into public.quests (id, title, emoji, points_reward, ends_at) values
  ('q1', 'Rescue 3 items before they expire', '🥦', 30, now() + interval '9 hours 22 minutes'),
  ('q2', 'Try a leftover recipe suggestion', '🍲', 20, now() + interval '9 hours 22 minutes'),
  ('q3', 'Log a fridge item every day for 5 days', '📦', 50, now() + interval '2 days 9 hours 22 minutes'),
  ('q4', 'Invite a friend to EcoHabit', '🤝', 40, now() + interval '5 days')
on conflict (id) do nothing;
