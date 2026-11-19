import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import agent
import persona

class PersonalityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.memory = patch.object(persona, 'MEMORY_FILE', str(Path(self.tmp.name) / 'memory.json'))
        self.memory.start()
        self.addCleanup(self.memory.stop)

    def test_old_memory_remains_readable(self):
        Path(persona.MEMORY_FILE).write_text('{"recent":[{"text":"hello","kind":"tea"}],"counts":{}}')
        self.assertEqual(persona.recent_messages(), ['hello'])
        persona.remember('lunch', 'Lunch time, machanla.', style='plain')
        self.assertEqual(len(persona.recent_messages()), 2)

    def test_close_wording_rejected(self):
        persona.remember('lunch', 'Lunch deserves your full attention today.')
        self.assertTrue(persona.repeated('Lunch deserves your full attention today!'))
        self.assertFalse(persona.repeated('Machanla, take a proper break.'))

    def test_styles_dont_repeat_or_overuse_dev_jokes(self):
        persona.remember('lunch', 'Hello', style='dev')
        for _ in range(40):
            self.assertNotEqual(persona.choose_style()[0], 'dev')

    def test_gif_cooldown_and_no_consecutive(self):
        with patch.object(agent, 'SEND_GIF', True), patch.object(agent, 'GIF_CHANCE', 1), patch.object(agent, 'GIFS', {'lunch':['one','two'], 'tea':['three']}):
            persona.remember('lunch', 'Lunch', gif_url='one')
            self.assertIsNone(agent.pick_gif('tea'))
            persona.remember('tea', 'Tea')
            self.assertEqual(agent.pick_gif('lunch'), 'two')

    def test_disabled_gifs_never_selected(self):
        with patch.object(agent, 'SEND_GIF', False):
            self.assertIsNone(agent.pick_gif('lunch'))

    def test_failed_send_never_retried_or_remembered(self):
        with patch.object(agent, 'OPENAI_API_KEY', 'test'), patch.object(agent, 'ALLOW_STATIC_FALLBACK', True), patch.object(agent, 'get_today_menu', return_value='Rice'), patch.object(agent, 'weather_now', return_value=None), patch.object(agent, 'draft_break', return_value=('Lunch time.', 'plain')), patch.object(agent, 'pick_gif', return_value=None), patch.object(agent, 'send_payload', side_effect=TimeoutError) as send:
            with self.assertRaises(TimeoutError):
                agent.run_break('lunch')
            send.assert_called_once()
            self.assertEqual(persona.recent_messages(), [])

    def test_only_break_times_have_jitter(self):
        with patch.object(agent, 'BackgroundScheduler') as scheduler, patch.object(agent, 'log_llm_config'):
            agent.schedule(background=True)
            for call in scheduler.return_value.add_job.call_args_list:
                trigger = call.args[1]
                expected = agent.BREAK_JITTER_SECONDS if call.args[0] is agent.scheduled_break else None
                self.assertEqual(trigger.jitter, expected)

if __name__ == '__main__': unittest.main()
