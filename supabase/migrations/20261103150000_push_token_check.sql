-- The push token check used the pattern {32,512}, but PostgreSQL patterns
-- allow at most 255 repetitions, so the check itself raised "invalid regular
-- expression" (2201B) and no iPhone could ever register for announcements.
-- Same rule, written so PostgreSQL accepts it.
alter table public.push_devices drop constraint if exists push_devices_token_check;
alter table public.push_devices add constraint push_devices_token_check
  check (token ~ '^[0-9a-f]+$' and char_length(token) between 32 and 512);
