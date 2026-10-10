# Paper Danfo Playtest Survey — portable build

A standalone, self-hosted copy of the survey. Drop the whole folder into any static host; responses still land in your Supabase `survey_responses` table.

## What's in the box

- `index.html` — the survey. Opens by default; no login or build step required.
- `images/` — the 7 Aki & Pawpaw meme images (welcome, runs, difficulty, kegs, controls, garage, thanks). The "How fun" page falls back to the paper sticker because the source image kept corrupting on download — swap it in later by dropping a working `fun.jpg` here and re-wiring one line in `index.html`.
- `GHU-survey.sql` — the Supabase schema (already run; kept here for reference).

## Deploy in 10 seconds

1. Open **https://app.netlify.com/drop**
2. Drag this whole folder (the one containing `index.html`) onto the page.
3. Copy the URL Netlify gives you (looks like `https://sparkly-danfo-abc123.netlify.app`).
4. Post it anywhere — WhatsApp, Twitter, itch devlog, Discord.

No account needed for a one-off; adding a free account lets you rename the site and keep it alive.

### Other free hosts that work the same way

- **Cloudflare Pages** — connect a GitHub repo, free, custom domain support.
- **GitHub Pages** — push the folder to a repo's `main` branch, enable Pages.
- **itch.io** — upload the folder as a zipped HTML game asset in your project.

## How submissions reach you

The HTML POSTs to `https://qmztlynivltrylffpwem.supabase.co/rest/v1/rpc/submit_survey` using your Supabase publishable key (embedded in the HTML — this is designed to be public; RLS prevents anyone reading responses). Rate limit is 60 submissions/minute globally.

Read responses in:
- **Supabase Studio** → Table Editor → `survey_responses`
- **Dashboard view**: run `select * from survey_report;` in SQL Editor
- **Quick tally**: run `select * from survey_tally;`

## Local test before you ship

The page needs to be served over `http://` or `https://` — opening `index.html` by double-click will **not** reach Supabase (CORS blocks `file://` origins). Quickest local test:

```
cd portable/
python3 -m http.server 8000
# then open http://localhost:8000
```

Submit a test response, confirm it lands in Supabase, then drop the folder on Netlify.

## Changing anything

- **Captions under each meme**: edit the `MEMES = { … }` object in `index.html`.
- **Questions**: edit the `PAGES = [ … ]` array in the same file.
- **Thanks message**: search for `You too much` and change the string.
- **Progress bar colour**: search for `--mustard` in the top CSS block.

After editing, just re-upload the whole folder to Netlify Drop — same URL stays.
