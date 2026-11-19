import unittest
from unittest.mock import patch
import agent


def buttons(payload):
    for sec in payload.get('cardsV2', [{}])[0].get('card', {}).get('sections', []):
        for w in sec['widgets']:
            if 'buttonList' in w:
                return w['buttonList']['buttons']
    return []


class QuestionTests(unittest.TestCase):
    def test_morning_has_no_menu_and_always_has_buttons(self):
        with patch.object(agent, 'get_today_menu', lambda k: 'Rice & curry'), \
             patch.object(agent, 'compose', lambda k: 'Good morning'), \
             patch.object(agent, 'QUESTION_CHANCE', 0), \
             patch.object(agent, 'BOT_PUBLIC_URL', 'https://bot.test'):
            p = agent.morning_payload()
        self.assertNotIn('Rice', str(p))
        b = buttons(p)
        self.assertEqual(len(b), agent.NUM_QUESTIONS)
        self.assertTrue(all(x['onClick']['openLink']['url'].startswith('https://bot.test/ask?q=') for x in b))

    def test_only_future_meals_are_asked(self):
        for _ in range(50):
            for after, meals in (('lunch', {'tea'}), ('juice', {'lunch', 'tea'}), ('tea', set())):
                qs = [k for k, _ in agent.pick_questions(after)]
                self.assertEqual(sum(k.startswith('gh:') for k in qs), 1)
                self.assertTrue({k for k in qs if not k.startswith('gh:')} <= meals)
                self.assertTrue(all(agent.is_question(k) for k in qs))

    def test_question_chance_zero_means_no_buttons(self):
        with patch.object(agent, 'QUESTION_CHANCE', 0), patch.object(agent, 'BOT_PUBLIC_URL', 'https://bot.test'):
            self.assertEqual(buttons(agent.break_payload('Lunch.', 'lunch', 'Rice')), [])
        with patch.object(agent, 'QUESTION_CHANCE', 1), patch.object(agent, 'BOT_PUBLIC_URL', 'https://bot.test'):
            self.assertTrue(buttons(agent.break_payload('Lunch.', 'lunch', 'Rice')))

    def test_answers_use_sheet_verbatim(self):
        with patch.object(agent, 'get_today_menu', lambda k: 'Mango juice' if k == 'juice' else None):
            self.assertIn('Mango juice', agent.answer_question('juice'))
            self.assertIn("isn't on the sheet", agent.answer_question('lunch'))


if __name__ == '__main__':
    unittest.main()
