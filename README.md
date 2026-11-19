# 🍛 Break-time Agent

A LangChain + OpenAI agent that keeps the **Agent Manager Team** fed, caffeinated and on time. It posts AI-written lunch and tea reminders, a morning menu preview and a weather-aware commute reminder to Google Chat. It also exposes a chat endpoint for sending announcements on demand.

## What it does

| Time (Mon–Fri) | Message | Group |
|---|---|---|
| **09:30** | ☀️ Morning hello with 3 random question buttons (*What's for lunch?*, *Any juice today?*...). No menu in the message | Team group |
| **12:30** | 🍛 AI-written lunch reminder, the day's menu and a GIF | Team group |
| **13:30** | 🚗 "Don't forget to book the commute!" plus a rain forecast for the evening | Commute group |
| **15:30** | ☕ AI-written tea reminder, the day's menu and a GIF | Team group |

- **Fresh every time:** the AI writes each lunch and tea message in a dry, witty dev-teammate tone, with emojis that match the actual food.
- **The menu is always exact.** The day's items are copied word for word from the Google Sheet onto their own bold line, never rewritten by the AI. If a cell is empty, the message is just generic.
- **Weather-aware commute:** checks the Open-Meteo forecast for 4–8 PM and warns early if rain is likely (no API key needed).
- **No weekend messages:** nothing scheduled is sent on Saturday or Sunday.
- **Separate groups:** the commute group is only posted to by the scheduler. The chat endpoint can't reach it.

## Chat endpoint

Standard chat interface: **`POST /chat`** on port **8000**.

```json
// Request
{ "message": "Announce to everyone with @all: release freeze starts tomorrow at 10am", "session_id": "s1", "context": {} }
// Response
{ "response": "I posted the announcement ..." }
```

Things you can ask:
- *"What's for lunch today?"* answers from the menu sheet.
- *"What's the schedule?"*
- *"Send the lunch message now"* or *"Send tea now"*.
- *"Tell everyone the standup moved to 3pm"* writes and posts a clear message for you.
- *"Announce with @all: ..."* posts a highlighted 📢 card; urgent notices get a 🚨 card.
- *Send exactly: "..."* posts your text word for word.

The agent only posts when you clearly ask, and its reply tells you exactly what was sent. `GET /health` returns `{"status":"ok"}`.

> ⚠️ Anyone who can reach `/chat` can post to the team group, so keep the endpoint private.

## Morning question buttons

The morning message no longer lists the menu. It carries 3 random buttons picked from breakfast, lunch, tea and juice questions. Each button opens **`GET /ask?q=<breakfast|lunch|tea|juice>`** on this bot, which:

- answers from the menu sheet (items copied verbatim) on a small page, and
- posts the same answer to the team group (`ASK_POST_TO_GROUP`), at most once per question every `ASK_COOLDOWN_SECONDS` so repeated taps don't spam.

Set `BOT_PUBLIC_URL` to where the bot is reachable (Google Chat webhooks can only attach link buttons, so the URL must be reachable from people's browsers). Without it, the questions appear as plain text.

### Surprise questions on other messages

Juice and lunch messages add 1 or 2 question buttons with probability `QUESTION_CHANCE` (default `0.5`). They only ask about today's meals still ahead (the sheet has only today's menu): the juice message asks about lunch and tea, the lunch message about tea. Tea and Friday messages come after the last meal, so they never get questions. Menu items sit in a small card under the message, copied exactly from the sheet.

### Agent Manager repo questions

Every set of question buttons includes exactly one random question about [wso2/agent-manager](https://github.com/wso2/agent-manager), from 21 options: best committer this week, open issues, open PRs, PRs merged this week, open bugs, oldest open issue, latest release and more (see `repo.py`). Answers come live from the GitHub API, cached for 5 minutes. Because of this, tea and Friday messages can also get a repo question. `/chat` can answer these questions too.

Set `GITHUB_TOKEN` (a token with no scopes is enough) to raise GitHub's rate limit. It is optional.

## Daily menu sheet

Google Sheet with the columns **`date | day | lunch | tea`** (dates as `YYYY-MM-DD`; `day` is optional and ignored). Fill in each day's row in the morning, or the whole week at once. Share the sheet as **"Anyone with the link can view"** and set `MENU_SHEET_URL` to its normal share link.

## Configuration (environment variables)

**Required**

| Variable | Description |
|---|---|
| `OPENAI_API_KEY` | OpenAI API key |
| `GOOGLE_CHAT_WEBHOOK_URL` | Incoming webhook of the team group |

**Schedule & tone**

| Variable | Default | Description |
|---|---|---|
| `LUNCH_TIMES` | `12:30` | Comma-separated; `12:30`, `12.30` and `12:30 PM` all work |
| `TEA_TIMES` | `15:30` | |
| `BOT_PUBLIC_URL` | — | Public base URL of the bot, used by the morning buttons |
| `ASK_POST_TO_GROUP` | `true` | Post button answers into the group too |
| `GITHUB_TOKEN` | — | Optional; raises the GitHub API rate limit for repo questions |
| `QUESTION_CHANCE` | `0.5` | Chance that non-morning messages carry surprise question buttons |
| `ASK_COOLDOWN_SECONDS` | `600` | Min seconds between group posts for the same question |
| `MORNING_TIMES` | `09:30` | Morning hello + question buttons; `off` disables it (old name `MENU_PREVIEW_TIMES` also works) |
| `TIMEZONE` | `Asia/Colombo` | |
| `SCHEDULE_DAYS` | `mon-fri` | Days for the lunch and tea messages |
| `SKIP_WEEKENDS` | `true` | Blocks every scheduled message on Saturday and Sunday |
| `TEAM_NAME` | `Agent Manager Team` | |
| `VIBE` | `casual, dry and witty like a dev teammate, generous with food emojis` | Tone of the AI messages |
| `OPENAI_MODEL` | `gpt-4o-mini` | |
| `ALLOW_STATIC_FALLBACK` | `false` | Send a fixed backup message if AI generation fails |

**Menu, GIFs & commute**

| Variable | Default | Description |
|---|---|---|
| `MENU_SHEET_URL` | — | Google Sheet share link (or a CSV link) |
| `SEND_GIF` | `false` | Enable occasional curated GIFs on lunch and tea reminders |
| `LUNCH_GIF_URLS` / `TEA_GIF_URLS` | built-in | Your own GIF links, comma-separated |
| `COMMUTE_WEBHOOK_URL` | — | Commute group webhook; leave empty to turn the commute reminder off |
| `COMMUTE_TIMES` | `13:30` | |
| `COMMUTE_MESSAGE` | `🚗 Don't forget to book the commute!` | |
| `WEATHER_ENABLED` | `true` | |
| `WEATHER_LAT` / `WEATHER_LON` | `6.9271` / `79.8612` | Colombo |
| `WEATHER_FROM_HOUR` / `WEATHER_TO_HOUR` | `16` / `20` | Evening commute window |
| `RAIN_THRESHOLD` | `50` | % chance of rain that triggers the warning |

## Build & run

- **Runtime:** Python 3.11 · **Start command:** `python main.py` · **Agent type:** Chat Agent (port 8000)
- Dependencies install automatically from `requirements.txt`.
- Run **one copy only**: each copy runs its own scheduler, so two copies would send every message twice.

Manual triggers (handy for testing):

```bash
python agent.py --now lunch     # or: tea | menu | commute
```

## Project structure

```
main.py           # FastAPI /chat endpoint + starts the scheduler
agent.py          # scheduler, AI message generation, menu sheet, weather, Google Chat posting
requirements.txt
.env.example      # all settings with defaults
```


## More natural AMEXA reminders

Lunch and tea drafts vary between plain nudges, dry observations, food opinions, invitations, callbacks and occasional developer jokes. Slang is optional, recent openings/jokes are checked against a varied bank of grounded starting points, and the last 60 posted messages are retained. AMEXA never claims real experiences or invents team reactions. Menus remain verbatim from the sheet.

`BREAK_JITTER_SECONDS=180` delays each scheduled lunch/tea reminder by zero to three minutes. It never sends before the nominal time. Commute, morning, juice and Friday schedule times are unchanged. There are no extra messages or follow-ups for silence. Set the delay to `0` for fixed times.

`SEND_GIF=true` enables curated GIF selection with `GIF_CHANCE=0.2` per eligible reminder. GIFs never occur on consecutive lunch/tea reminders and URLs used in the last six break reminders are excluded. Consequently the actual GIF frequency is lower than 20%, especially with a small collection. Existing `LUNCH_GIF_URLS` and `TEA_GIF_URLS` are used. Random Giphy search settings are no longer used.

Generate a review without posting: `.venv/bin/python preview_personality.py`. This uses the configured AI provider (normal API charges apply), the public meal sheet, and isolated temporary memory. It produces `previews/two_week.html` and `previews/two_week.json` for the next ten weekdays. It proposes GIFs enabled without changing `.env`; it never calls the Google Chat send endpoint. Run tests with `.venv/bin/python -m unittest discover -s tests -v`.

The changes are local until the agent is restarted or redeployed. Existing `.env` values are preserved. If GIFs are disabled there, they stay disabled until explicitly enabled. Posting failures are not retried with fallback messages because delivery might already have succeeded. No scheduler catch-up outside the existing five-minute misfire grace window is added.
