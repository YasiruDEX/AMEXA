import unittest
from unittest.mock import patch
import agent


class MorningQuestionTests(unittest.TestCase):
    def test_morning_has_no_menu_and_has_buttons(self):
        with patch.object(agent, 'get_today_menu', lambda k: 'Rice & curry'), \
             patch.object(agent, 'compose', lambda k: 'Good morning'), \
             patch.object(agent, 'BOT_PUBLIC_URL', 'https://bot.test'):
            p = agent.morning_payload()
        self.assertNotIn('Rice', p['text'])
        buttons = p['cardsV2'][0]['card']['sections'][0]['widgets'][0]['buttonList']['buttons']
        self.assertEqual(len(buttons), agent.NUM_QUESTIONS)
        self.assertTrue(all(b['onClick']['openLink']['url'].startswith('https://bot.test/ask?q=') for b in buttons))

    def test_answers_use_sheet_verbatim(self):
        with patch.object(agent, 'get_today_menu', lambda k: 'Mango juice' if k == 'juice' else None):
            self.assertIn('Mango juice', agent.answer_question('juice'))
            self.assertIn("isn't on the sheet", agent.answer_question('lunch'))


if __name__ == '__main__':
    unittest.main()
