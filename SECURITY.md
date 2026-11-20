# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 1.0.0-alpha | ✅ |

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Report them privately through [GitHub security advisories](https://github.com/YasiruDEX/AMEXA/security/advisories/new). Include steps to reproduce and the possible impact. We aim to reply within 5 working days.

## Deployment notes

- `POST /chat` can post to your Google Chat group. Keep it behind authentication.
- `GET /ask` is designed to be public. It only reads the menu sheet and GitHub, and it posts each answer at most once per `ASK_COOLDOWN_SECONDS`.
- Treat `GOOGLE_CHAT_WEBHOOK_URL`, `COMMUTE_WEBHOOK_URL`, `OPENAI_API_KEY` and `GITHUB_TOKEN` as secrets. Never commit `.env`.
