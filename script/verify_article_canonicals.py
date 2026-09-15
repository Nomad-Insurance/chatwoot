#!/usr/bin/env python3
"""Read-only D190 receipt. The portal origin is supplied through the environment."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from html import unescape
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import xml.etree.ElementTree as ET

CONFIG = Path(__file__).resolve().parents[1] / 'config/help_center_article_canonicals.json'


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Page(HTMLParser):
    def __init__(self, body):
        super().__init__()
        self.canonicals = []
        self.noindex = False
        self.links = set()
        self.next_data = ''
        self.in_next_data = False
        self.feed(body)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'link' and 'canonical' in attrs.get('rel', '').lower().split():
            self.canonicals.append(attrs.get('href', ''))
        if tag == 'meta' and attrs.get('name', '').lower() in ('robots', 'googlebot'):
            self.noindex |= 'noindex' in attrs.get('content', '').lower()
        if tag == 'a' and attrs.get('href'):
            self.links.add(attrs['href'])
        if tag == 'script' and attrs.get('id') == '__NEXT_DATA__':
            self.in_next_data = True

    def handle_endtag(self, tag):
        if tag == 'script':
            self.in_next_data = False

    def handle_data(self, data):
        if self.in_next_data:
            self.next_data += data


def fetch(url):
    try:
        request = Request(url, headers={'User-Agent': 'ChatwootCanonicalVerification/1.0'})
        with build_opener(NoRedirect).open(request, timeout=20) as response:
            return response.status, response.headers, response.read().decode('utf-8')
    except HTTPError as error:
        return error.code, error.headers, ''
    except (URLError, TimeoutError, UnicodeError, OSError):
        # Never echo exception text: it can include the private portal hostname.
        return 0, {}, ''


def normalized_content(value):
    # This is the measured comparison, not a claim of byte-identical Markdown.
    value = re.sub(r'\]\([^\n)]*\)', '](LINK)', value)
    return re.sub(r'\s+', ' ', unescape(value)).strip()


def verify_article(slug, included, config, origin):
    path = f"/hc/{config['portal_slug']}/articles/{slug}"
    expected = config['website_origin'] + config['website_prefix'] + slug if included else origin + path
    failures = []
    status, headers, body = fetch(origin + path)
    page = Page(body)
    if status != 200:
        failures.append(f'portal status {status}')
    if page.canonicals != [expected]:
        failures.append('canonical mismatch')
    if page.noindex or 'noindex' in headers.get('X-Robots-Tag', '').lower():
        failures.append('portal noindex')
    if included:
        status, headers, body = fetch(expected)
        website = Page(body)
        if status != 200:
            failures.append(f'website status {status}')
        if website.canonicals != [expected]:
            failures.append('website canonical mismatch')
        if website.noindex or 'noindex' in headers.get('X-Robots-Tag', '').lower():
            failures.append('website noindex')
        md_status, _, markdown = fetch(origin + path + '.md')
        try:
            article = json.loads(website.next_data)['props']['pageProps']['article']
            if article['slug'] != slug or not article.get('chatwootId'):
                failures.append('website source identity mismatch')
            if md_status != 200 or not markdown.strip() or normalized_content(article['content']) != normalized_content(markdown):
                failures.append('article content mismatch')
        except (KeyError, TypeError, ValueError):
            failures.append('website article data unavailable')
    return slug, included, failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workers', type=int, choices=range(1, 5), default=4)
    args = parser.parse_args()
    origin = os.environ.get('CHATWOOT_VERIFY_PORTAL_ORIGIN', '').rstrip('/')
    parsed = urlsplit(origin)
    local = parsed.hostname in ('127.0.0.1', 'localhost', '::1')
    if not parsed.hostname or parsed.username or parsed.password or parsed.path or parsed.query or parsed.fragment:
        parser.error('set CHATWOOT_VERIFY_PORTAL_ORIGIN to an origin without credentials or a path')
    if parsed.scheme != 'https' and not (local and parsed.scheme == 'http'):
        parser.error('HTTPS is required except for a loopback test server')
    config = json.loads(CONFIG.read_text())
    included = config['included_slugs']
    excluded = config['excluded_slugs']
    if len(included) != 74 or len(excluded) != 18 or len(set(included + excluded)) != 92:
        print('FAIL reviewed membership changed: expected 74 included and 18 excluded')
        return 1
    if any(not re.fullmatch(r'[a-z0-9-]+', slug) for slug in included + excluded):
        print('FAIL invalid membership slug')
        return 1
    expected_slugs = set(included + excluded)
    status, _, body = fetch(f"{origin}/hc/{config['portal_slug']}/sitemap.xml")
    try:
        locations = [element.text for element in ET.fromstring(body).iter() if element.tag.endswith('}loc')]
        expected_paths = {f"/hc/{config['portal_slug']}/articles/{slug}" for slug in expected_slugs}
        actual_paths = [urlsplit(location).path for location in locations if location]
        inventory_ok = status == 200 and len(actual_paths) == 92 and set(actual_paths) == expected_paths
    except (ET.ParseError, ValueError):
        inventory_ok = False
    website_status, _, website_body = fetch(config['website_origin'] + config['website_prefix'].rstrip('/'))
    linked_paths = {urlsplit(link).path for link in Page(website_body).links}
    website_slugs = {path[len(config['website_prefix']):] for path in linked_paths if path.startswith(config['website_prefix'])}
    expected_website = set(included) | {'how-and-when-to-precertify-with-morgan-white'}
    website_inventory_ok = website_status == 200 and website_slugs == expected_website
    tasks = [(slug, slug in included, config, origin) for slug in sorted(expected_slugs)]
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        rows = list(pool.map(lambda task: verify_article(*task), tasks))
    for slug, _, failures in rows:
        if failures:
            print(f"FAIL {slug}: {', '.join(failures)}")
    passed_included = sum(included and not failures for _, included, failures in rows)
    passed_excluded = sum(not included and not failures for _, included, failures in rows)
    print(f"portal inventory: {'PASS' if inventory_ok else 'FAIL'} (expected 92)")
    print(f"website inventory: {'PASS' if website_inventory_ok else 'FAIL'} (expected 75)")
    print(f'included: {passed_included}/74 PASS; excluded: {passed_excluded}/18 PASS')
    return 0 if inventory_ok and website_inventory_ok and passed_included == 74 and passed_excluded == 18 else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print(f'FAIL verifier unavailable ({type(error).__name__}); no successful receipt')
        sys.exit(1)
