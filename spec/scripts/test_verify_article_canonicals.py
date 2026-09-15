import importlib.util
from pathlib import Path
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[2] / 'script/verify_article_canonicals.py'
spec = importlib.util.spec_from_file_location('verifier', MODULE)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class VerificationTest(unittest.TestCase):
    def test_duplicate_canonicals_are_preserved_for_rejection(self):
        page = verifier.Page('<link href="/one" rel="canonical"><link rel="canonical" href="/two">')
        self.assertEqual(page.canonicals, ['/one', '/two'])

    def test_googlebot_noindex_is_detected(self):
        self.assertTrue(verifier.Page('<meta name="googlebot" content="noindex,follow">').noindex)

    def test_content_comparison_ignores_link_targets_but_not_contact_instructions(self):
        self.assertEqual(verifier.normalized_content('Read [help](/a).'), verifier.normalized_content('Read [help](https://example.test/b).'))
        self.assertNotEqual(verifier.normalized_content('Call the insurer.'), verifier.normalized_content('Call the broker.'))

    def test_transport_failure_cannot_become_a_pass(self):
        with patch.object(verifier, 'fetch', return_value=(0, {}, '')):
            _, _, failures = verifier.verify_article('example', False, {'portal_slug': 'example'}, 'https://example.test')
        self.assertIn('portal status 0', failures)
        self.assertIn('canonical mismatch', failures)

    def test_http_redirect_is_not_followed(self):
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(301)
                self.send_header('Location', '/target')
                self.end_headers()

            def log_message(self, *_args):
                pass

        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            status, _, _ = verifier.fetch(f'http://127.0.0.1:{server.server_port}/source')
            self.assertEqual(status, 301)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == '__main__':
    unittest.main()
