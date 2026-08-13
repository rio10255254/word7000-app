# Lock Screen learning reminder backend

The app and database integration are already implemented. Complete these steps once for production:

1. Run `supabase/schema.sql` in the Supabase SQL Editor.
2. Create an Apple Push Notifications key in Apple Developer, download the `.p8` file once, and note its Key ID.
3. Add these Edge Function secrets:
   - `APNS_TEAM_ID=3WYY3K64S5`
   - `APNS_KEY_ID=<Apple key ID>`
   - `APNS_PRIVATE_KEY=<full p8 contents>`
   - `APNS_BUNDLE_ID=com.rio.word7000`
   - `APNS_ENVIRONMENT=production`
   - `CRON_SECRET=<a long random value>`
4. Deploy `send-streak-live-activities` with JWT verification disabled.
5. Schedule an HTTP request every minute to the function URL with header `x-cron-secret: <CRON_SECRET>`.

The same scheduled function handles two reminders in each user's local time zone:

- A daily learning Live Activity between 12:00 and 13:00, shown once per local day.
- A streak countdown during the final hour before the streak expires.

The function atomically claims due devices, starts each Live Activity through APNs, and records failures for retry and diagnosis. Keep the schedule running every minute so noon delivery is prompt and failed sends can be retried.
