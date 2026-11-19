"""Read-only facts about the wso2/agent-manager GitHub repo, for question buttons and /chat."""
import logging
import os
import random
import time
from collections import Counter
from datetime import datetime, timedelta, timezone

import requests

log = logging.getLogger("break-bot")

REPO = "wso2/agent-manager"
REPO_URL = f"https://github.com/{REPO}"
API = "https://api.github.com"
# Optional: only raises the API rate limit (60/hour without it). The repo is public.
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")
CACHE_SECONDS = 300
_cache = {}


def _get(path: str, **params):
    key = (path, tuple(sorted(params.items())))
    hit = _cache.get(key)
    if hit and time.time() - hit[0] < CACHE_SECONDS:
        return hit[1]
    headers = {"Accept": "application/vnd.github+json"}
    if GITHUB_TOKEN:
        headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"
    r = requests.get(f"{API}{path}", params=params, headers=headers, timeout=15)
    r.raise_for_status()
    data = r.json()
    _cache[key] = (time.time(), data)
    return data


def _search(kind: str, q: str, **params):
    return _get("/search/issues", q=f"repo:{REPO} {kind} {q}".strip(), **params)


def _count(kind: str, q: str) -> int:
    return _search(kind, q, per_page=1)["total_count"]


def _week_ago() -> str:
    return (datetime.now(timezone.utc) - timedelta(days=7)).strftime("%Y-%m-%d")


def _ago(iso: str) -> str:
    days = (datetime.now(timezone.utc) - datetime.fromisoformat(iso.replace("Z", "+00:00"))).days
    return "today" if days == 0 else ("yesterday" if days == 1 else f"{days} days ago")


def _week_commits():
    """Last 7 days of non-merge commits on the default branch (up to 500)."""
    since = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    commits = []
    for page in range(1, 6):
        batch = _get(f"/repos/{REPO}/commits", since=since, per_page=100, page=page)
        commits += batch
        if len(batch) < 100:
            break
    return [c for c in commits if len(c.get("parents", [])) < 2]


def _login(commit) -> str:
    return (commit.get("author") or {}).get("login") or commit["commit"]["author"]["name"]


def top_committer():
    commits = _week_commits()
    if not commits:
        return "🏆 No commits this week. Suspiciously quiet."
    counts = Counter(_login(c) for c in commits if not _login(c).endswith("[bot]")).most_common(3)
    if not counts:
        return "🏆 Only bots committed this week."
    best, n = counts[0]
    rest = ", ".join(f"{u} ({c})" for u, c in counts[1:])
    return f"🏆 *Top committer this week:* {best} with {n} commits" + (f". Runners up: {rest}" if rest else "")


def commits_this_week():
    n = len(_week_commits())
    return f"📈 *Commits this week:* {n} (merge commits not counted)"


def contributors_this_week():
    people = {_login(c) for c in _week_commits()} - {""}
    people = {p for p in people if not p.endswith("[bot]")}
    return f"👥 *People who committed this week:* {len(people)}"


def last_commit():
    recent = _get(f"/repos/{REPO}/commits", per_page=20)
    c = next((x for x in recent if len(x.get("parents", [])) < 2), recent[0])
    msg = c["commit"]["message"].splitlines()[0]
    return f"🕒 *Latest commit:* \"{msg}\" by {_login(c)}, {_ago(c['commit']['author']['date'])}"


def open_issues():
    return f"🐞 *Open issues:* {_count('is:issue', 'is:open')}"


def open_prs():
    return f"🔀 *Open pull requests:* {_count('is:pr', 'is:open')}"


def bugs_open():
    n = _count("is:issue", 'is:open label:"Type/Bug"')
    return f"🐛 *Open bugs:* {n}"


def issues_opened_week():
    return f"🆕 *Issues opened this week:* {_count('is:issue', f'created:>={_week_ago()}')}"


def issues_closed_week():
    return f"✅ *Issues closed this week:* {_count('is:issue', f'closed:>={_week_ago()}')}"


def prs_merged_week():
    return f"🚀 *PRs merged this week:* {_count('is:pr', f'is:merged merged:>={_week_ago()}')}"


def prs_opened_week():
    return f"📬 *PRs opened this week:* {_count('is:pr', f'created:>={_week_ago()}')}"


def top_pr_author():
    items = _search("is:pr", f"created:>={_week_ago()}", per_page=100)["items"]
    counts = Counter(i["user"]["login"] for i in items if not i["user"]["login"].endswith("[bot]"))
    if not counts:
        return "✍️ No PRs opened this week yet."
    user, n = counts.most_common(1)[0]
    return f"✍️ *Most PRs opened this week:* {user} with {n}"


def top_merger():
    items = _search("is:pr", f"is:merged merged:>={_week_ago()}", per_page=100)["items"]
    counts = Counter(i["user"]["login"] for i in items if not i["user"]["login"].endswith("[bot]"))
    if not counts:
        return "🎯 No PRs merged this week yet."
    user, n = counts.most_common(1)[0]
    return f"🎯 *Most PRs merged this week:* {user} with {n}"


def _one(kind, q, sort, order, label, icon):
    items = _search(kind, q, sort=sort, order=order, per_page=1)["items"]
    if not items:
        return f"{icon} Nothing found for that one."
    i = items[0]
    return f"{icon} *{label}:* #{i['number']} {i['title']} ({_ago(i['created_at'])})"


def oldest_open_issue():
    return _one("is:issue", "is:open", "created", "asc", "Oldest open issue", "🦖")


def newest_issue():
    return _one("is:issue", "is:open", "created", "desc", "Newest open issue", "🐣")


def hottest_issue():
    items = _search("is:issue", "is:open", sort="comments", order="desc", per_page=1)["items"]
    if not items:
        return "🔥 No open issues."
    i = items[0]
    return f"🔥 *Most discussed open issue:* #{i['number']} {i['title']} ({i['comments']} comments)"


def oldest_open_pr():
    return _one("is:pr", "is:open", "created", "asc", "Longest waiting open PR", "⏳")


def latest_merged_pr():
    items = _search("is:pr", "is:merged", sort="updated", order="desc", per_page=1)["items"]
    if not items:
        return "🔀 No merged PRs found."
    i = items[0]
    return f"🔀 *Latest merged PR:* #{i['number']} {i['title']} by {i['user']['login']}"


def latest_release():
    try:
        r = _get(f"/repos/{REPO}/releases/latest")
        return f"🏷️ *Latest release:* {r.get('name') or r['tag_name']} ({_ago(r['published_at'])})"
    except requests.HTTPError:
        return "🏷️ No releases published yet."


def stars():
    d = _get(f"/repos/{REPO}")
    return f"⭐ *Stars:* {d['stargazers_count']}  ·  *Forks:* {d['forks_count']}"


def top_contributor():
    c = _get(f"/repos/{REPO}/contributors", per_page=3)
    people = [x for x in c if not x["login"].endswith("[bot]")]
    if not people:
        return "👑 No contributors found."
    return f"👑 *All-time top contributor:* {people[0]['login']} with {people[0]['contributions']} commits"


# key -> (button label, answer function)
QUESTIONS = {
    "top_committer": ("🏆 Best committer this week?", top_committer),
    "open_issues": ("🐞 How many open issues?", open_issues),
    "open_prs": ("🔀 Open PRs right now?", open_prs),
    "prs_merged": ("🚀 PRs merged this week?", prs_merged_week),
    "prs_opened": ("📬 PRs opened this week?", prs_opened_week),
    "issues_closed": ("✅ Issues closed this week?", issues_closed_week),
    "issues_opened": ("🆕 New issues this week?", issues_opened_week),
    "commits_week": ("📈 Commits this week?", commits_this_week),
    "committers_week": ("👥 How many people committed this week?", contributors_this_week),
    "last_commit": ("🕒 What was the last commit?", last_commit),
    "bugs": ("🐛 How many open bugs?", bugs_open),
    "top_pr_author": ("✍️ Who opened the most PRs this week?", top_pr_author),
    "top_merger": ("🎯 Who got the most PRs merged?", top_merger),
    "oldest_issue": ("🦖 Oldest open issue?", oldest_open_issue),
    "newest_issue": ("🐣 Newest open issue?", newest_issue),
    "hottest_issue": ("🔥 Most discussed open issue?", hottest_issue),
    "oldest_pr": ("⏳ Which PR has waited longest?", oldest_open_pr),
    "latest_pr": ("🔀 Latest merged PR?", latest_merged_pr),
    "release": ("🏷️ What's the latest release?", latest_release),
    "stars": ("⭐ How many stars do we have?", stars),
    "top_contributor": ("👑 All-time top contributor?", top_contributor),
}


def random_question():
    """One random (key, label) repo question."""
    key = random.choice(list(QUESTIONS))
    return key, QUESTIONS[key][0]


def answer(key: str) -> str:
    if key not in QUESTIONS:
        raise ValueError(f"unknown repo question: {key}")
    try:
        return f"{QUESTIONS[key][1]()}\n🔗 {REPO_URL}"
    except Exception:
        log.exception("GitHub lookup failed for %s", key)
        return "🤖 Couldn't reach GitHub just now. Try again in a bit."
