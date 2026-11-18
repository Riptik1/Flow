-- =====================================================================
-- Flow – Supabase: realtime access policies ONLY (safe to run repeatedly)
-- Your tables and edge functions already exist and are not touched.
-- Run in: Dashboard -> SQL Editor -> New query -> Run
-- =====================================================================

-- The apps join the PRIVATE broadcast channel  link:<device_link_id>:flow
-- Only the Mac and the iPhone of an active (not revoked) link may listen or send.
drop policy if exists "flow link: receive" on realtime.messages;
drop policy if exists "flow link: send"    on realtime.messages;

create policy "flow link: receive" on realtime.messages
  for select to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and exists (
      select 1 from public.device_links l
      where l.revoked_at is null
        and realtime.topic() = 'link:' || l.id::text || ':flow'
        and (l.mac_id = (select auth.uid()) or l.iphone_id = (select auth.uid()))
    )
  );

create policy "flow link: send" on realtime.messages
  for insert to authenticated
  with check (
    realtime.messages.extension = 'broadcast'
    and exists (
      select 1 from public.device_links l
      where l.revoked_at is null
        and realtime.topic() = 'link:' || l.id::text || ':flow'
        and (l.mac_id = (select auth.uid()) or l.iphone_id = (select auth.uid()))
    )
  );

-- ---------------------------------------------------------------------
-- Checks (run separately and read the result):
-- 1) edge function "redeem-pairing-code" upserts with onConflict 'mac_id,iphone_id',
--    which needs a UNIQUE constraint on exactly those columns. Should return a row:
--      select indexdef from pg_indexes
--      where tablename = 'device_links' and indexdef ilike '%unique%';
-- 2) Existing policies on your tables (the apps read/write these directly):
--      select tablename, policyname, cmd from pg_policies
--      where schemaname in ('public','realtime') order by 1, 2;
