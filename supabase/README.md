# Flow – Supabase (project zaecghzqdojvlguamtlk)

Used only for **remote access**. Subscriptions are StoreKit 2.

The edge functions `generate-pairing-code`, `redeem-pairing-code`, `leave-device-group`
and the tables `mac_devices`, `iphone_devices`, `device_links`, `pairing_codes` already
exist in the project and match the apps. Do not redeploy other versions.

## To do
1. Authentication -> Sign In / Providers -> "Allow anonymous sign-ins" = ON (already on).
2. Run `setup.sql` once (adds the realtime policies for the private channel).
3. Make sure `device_links` has a UNIQUE constraint on (mac_id, iphone_id) – see the checks in `setup.sql`.
4. Realtime -> Settings: "Allow public access" OFF.

## Free plan
* Paused after 7 days of inactivity – add a daily keep-alive request or upgrade.
* Realtime quotas (~200 connections, 100 msg/s, 2M msg/month): fine for mouse/keyboard/files,
  but remote app-mirroring video would use the monthly quota quickly.
