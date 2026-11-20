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

[Unreleased]: https://github.com/YasiruDEX/AMEXA/compare/v1.0.0-alpha...HEAD
[1.0.0-alpha]: https://github.com/YasiruDEX/AMEXA/releases/tag/v1.0.0-alpha
