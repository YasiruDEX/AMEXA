"""Generate ten working days through the real drafting path; never send messages."""
import html
import json
import random
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import agent
import persona


def main():
    random.seed(42)
    now = datetime.now(ZoneInfo(agent.TIMEZONE))
    day = now.date() + timedelta(days=1)
    rows = agent._menu_rows() or []
    menus = {agent._parse_date(r.get('date', '')): r for r in rows}
    output = []
    original_memory = persona.MEMORY_FILE
    original_gifs = agent.SEND_GIF
    # Propose enabling GIFs in the sample without modifying the user's .env.
    agent.SEND_GIF = True
    try:
        with tempfile.TemporaryDirectory() as tmp:
            persona.MEMORY_FILE = str(Path(tmp) / 'preview.json')
            for _ in range(10):
                while day.weekday() >= 5:
                    day += timedelta(days=1)
                for kind, times in [('lunch', agent.LUNCH_TIMES), ('tea', agent.TEA_TIMES)]:
                    for time in agent.time_list(times):
                        hour, minute = agent.parse_time(time)
                        nominal = datetime.combine(day, datetime.min.time(), tzinfo=ZoneInfo(agent.TIMEZONE)).replace(hour=hour, minute=minute)
                        scheduled = nominal + timedelta(seconds=random.uniform(0, agent.BREAK_JITTER_SECONDS))
                        item = menus.get(day, {}).get(kind) or None
                        try:
                            text, style = agent.draft_break(kind, scheduled, item)
                        except RuntimeError:
                            text, style = '[SKIPPED: all drafts too repetitive]', 'skipped'
                        gif = agent.pick_gif(kind) if style != "skipped" else None
                        persona.remember(kind, text, style=style, gif_url=gif) if style != "skipped" else None
                        output.append({'at': scheduled.isoformat(timespec='seconds'), 'kind': kind, 'style': style, 'message': agent.with_menu(text, kind, item), 'gif': gif})
                        print(f'{day} {kind}: draft ready', flush=True)
                day += timedelta(days=1)
    finally:
        persona.MEMORY_FILE = original_memory
        agent.SEND_GIF = original_gifs
    Path('previews').mkdir(exist_ok=True)
    Path('previews/two_week.json').write_text(json.dumps(output, ensure_ascii=False, indent=2))
    cards = ''.join('<article><small>' + html.escape(r['at'] + ' | ' + r['kind'] + ' | ' + r['style']) + '</small><p>' + html.escape(r['message']).replace('\n', '<br>') + '</p>' + ('<a href="' + html.escape(r['gif'], quote=True) + '">Selected GIF</a>' if r['gif'] else '<small>No GIF</small>') + '</article>' for r in output)
    Path('previews/two_week.html').write_text('<!doctype html><meta charset="utf-8"><title>AMEXA personality preview</title><style>body{font:16px system-ui;max-width:850px;margin:40px auto;background:#100703;color:#eee;padding:20px}article{border:1px solid #483022;border-radius:12px;padding:20px;margin:14px 0}small{color:#b9ada5}a{color:#ff7918}p{line-height:1.6}</style><h1>AMEXA: ten working days</h1><p>Review only. Nothing was posted. Actual sheet menus where available; no invented menus. Proposed GIFs enabled. Times use ' + html.escape(agent.TIMEZONE) + '. Morning, juice and commute reminders are outside this lunch/tea sample.</p>' + cards)
    print('Saved preview; no Chat messages sent.')


if __name__ == '__main__':
    main()
