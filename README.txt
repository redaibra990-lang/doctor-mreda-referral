DOCTOR MReda ⚡️ — Live referral site

1) Run setup.sql in the SAME Supabase project once.
2) index.html is already configured with the Supabase project URL and publishable key.
3) Upload the folder to a static host such as Vercel/Netlify/GitHub Pages.

Important:
- The Supabase publishable key is intended for frontend use; never put a service_role/secret key in this file.
- This system tracks registrations, not verified WhatsApp Channel follows, because WhatsApp does not expose a public per-user channel-follow verification API.
- visitor_id is stored in localStorage. It helps prevent casual duplicate registration, but it is not a fraud-proof identity system.
- For a serious contest, manually verify winners and exclude suspicious/duplicate entries.
