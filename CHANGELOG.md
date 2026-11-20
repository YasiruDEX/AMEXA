# Changelog

All notable changes to AMEXA are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0-alpha] - 2026-11-20

First public alpha.

### Added
- Scheduled Google Chat messages: morning hello, juice, lunch, tea, Friday wind-down and commute reminders.
- Daily menu from a Google Sheet, always shown word for word.
- Question buttons backed by `GET /ask`. The morning message always has them; other messages get them by `QUESTION_CHANCE`, and they only ask about meals still ahead today.
- 21 read-only questions about the wso2/agent-manager GitHub repository, one per button set.
- `POST /chat` endpoint for questions, messages and announcements.
- AMEXA persona with memory to avoid repeated wording, optional curated GIFs and timing jitter.
- Evening rain forecast on the commute reminder via Open-Meteo.
- OpenAI, Groq or any OpenAI-compatible model.
- Flutter companion app for viewing the menu.

## [0.11.0] - 2026-11-19

- Surprise question buttons on other messages and agent-manager repo insights.

## [0.10.0] - 2026-11-19

- Morning message asks questions through buttons backed by `/ask` instead of listing the menu.

## [0.9.0] - 2026-10-29

- Flutter companion app for viewing the menu.

## [0.8.0] - 2026-10-22

- Juice reminder driven by the sheet, default morning schedule and LLM config logging.

## [0.7.0] - 2026-10-20

- Groq and other OpenAI-compatible model providers.

## [0.6.0] - 2026-10-19

- Shorter messages, stricter emoji rules and support for disabled schedules.

## [0.5.0] - 2026-10-16

- Persona module, breakfast menu, morning menu preview and rain-aware commute reminder.

## [0.4.0] - 2026-10-16

- Daily menu from Google Sheets, appended to messages word for word.

## [0.3.0] - 2026-10-16

- GIF attachments, weekday commute reminder and weekend skipping.

## [0.2.0] - 2026-10-16

- Dry, witty dev-teammate persona and announcement cards.

## [0.1.0] - 2026-10-16

- Scheduled lunch and tea reminders for Google Chat and the FastAPI chat server.

[Unreleased]: https://github.com/YasiruDEX/AMEXA/compare/v1.0.0-alpha...HEAD
[1.0.0-alpha]: https://github.com/YasiruDEX/AMEXA/releases/tag/v1.0.0-alpha
[0.11.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.11.0
[0.10.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.10.0
[0.9.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.9.0
[0.8.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.8.0
[0.7.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.7.0
[0.6.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.6.0
[0.5.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.5.0
[0.4.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.4.0
[0.3.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.3.0
[0.2.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.2.0
[0.1.0]: https://github.com/YasiruDEX/AMEXA/releases/tag/v0.1.0
