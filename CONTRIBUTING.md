# Contributing to AMEXA

Thanks for helping make AMEXA better. This guide covers how to report issues, propose changes and send pull requests.

## Ways to contribute

- **Report a bug** with the bug report template. Include what you expected, what happened, and the relevant log lines (remove any webhook URLs or keys).
- **Suggest a feature** with the feature request template. Explain the HR task or team problem it solves.
- **Improve the docs**, including typos, unclear settings and missing examples.
- **Send code** for open issues. Comment on the issue first so work isn't duplicated.

## Development setup

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python -m unittest discover -s tests -v
```

Use a **test Google Chat space** and its own webhook while developing. Never point a development copy at your team's real group.

## Pull requests

1. Fork the repository and create a branch from `main`, for example `feat/leave-reminders` or `fix/menu-date-parsing`.
2. Keep each change focused. One feature or fix per pull request.
3. Add or update tests in `tests/` for behaviour changes, and make sure all tests pass.
4. Update `README.md` and `.env.example` when you add or change a setting.
5. Add a line under **Unreleased** in `CHANGELOG.md`.
6. Write commit messages in the imperative mood, for example `add leave reminder`.

## House rules for messages

AMEXA's messages follow a few rules. Please keep them:

- Menu items are shown **exactly** as written in the sheet. The AI never rewrites them.
- No em or en dashes in posted messages (`clean()` enforces this).
- The AI never invents events, availability or team reactions.
- Scheduled messages never go out on weekends unless `SKIP_WEEKENDS=false`.

## Code of Conduct

By taking part, you agree to follow our [Code of Conduct](CODE_OF_CONDUCT.md).
