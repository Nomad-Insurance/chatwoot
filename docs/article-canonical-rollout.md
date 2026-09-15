# D190 article canonicals

The website is the preferred search result for the 74 reviewed matching article
pairs. Portal pages continue to serve users. This is a fork patch, not a portal
setting. Carry the additive PortalHostPolicy method, configuration and request tests through upgrades.

## Membership and ownership

Michael owns `config/help_center_article_canonicals.json`. The 74 included slugs
use the same slug below `/articles/support/` on the website. The configuration
is scoped to one portal and locale. It is not a rule for all articles or tenants.
The article selection method also requires the article to belong to that portal and account.

The bounded baseline is 92 portal sitemap articles and 75 website-index articles.
There are 18 exclusions: 17 absent from that website index and
`how-and-when-to-precertify-with-morgan-white`, whose content differs. Its content
must be handled by its owner separately; do not add it merely because its URL
exists. New or excluded slugs keep the existing self-canonical behavior.

Before publishing an allowlist addition, verify the website URL returns 200,
self-canonicalizes, permits indexing, and has the matching article content.
Publishing a website counterpart alone does not grant eligibility. Renaming or
removing a website article requires updating/removing its allowlist entry first,
then deploying that change before changing the website. Coordinate content edits
on either side as well. An uncoordinated website change can leave a stale target
until the manual verification detects it. No scheduled check is installed.

## Verification receipt

Use Python 3 (standard library only). Supply the authorized portal origin through
`CHATWOOT_VERIFY_PORTAL_ORIGIN` in the operator's shell; do not paste it in an
issue, PR, command transcript or this runbook. The script never prints origins,
response bodies, source identifiers or exception details. HTTP is accepted only
for loopback test servers; public reads require HTTPS. Redirects are not followed.

```sh
python3 script/verify_article_canonicals.py
```

Expected after rollout:

```text
portal inventory: PASS (expected 92)
website inventory: PASS (expected 75)
included: 74/74 PASS; excluded: 18/18 PASS
```

Exit 0 is a pass. Any inventory, HTTP, canonical, indexing, article-identity or
content mismatch exits 1. The measured content comparison normalizes whitespace,
HTML entities and Markdown link destinations; it does not claim byte identity.
The exclusions are not automatically reclassified. A changed inventory needs a
reviewed membership update and adjusted expected counts, not suppression of the
failure. Run before and after rollout and before coordinated editorial changes.
Retain timestamp, tested commit, counts and exit status with the receipt.

Before implementation, all 74 included pages are expected to fail with canonical
mismatches while the 18 exclusions pass. A local fixture-server result must be
labelled local; it does not prove deployment or Google's selected canonical.

Run focused Rails tests, including both layouts, query parameters, excluded and
new slugs, another locale, another portal/account, host redirects and previews.
Three blocking tests must detect their corresponding temporary mutations:

- Remove the article selection method's portal-slug guard: another tenant must fail.
- Route a disallowed-host redirect through the website article selection: the portal redirect assertion must fail.
- Route sitemap origin selection through the website origin: the portal sitemap assertion must fail.

Restore each mutation before the next, then run all focused tests successfully.
Never commit a mutation. The redirect and sitemap fences are the existing callers'
exclusive use of portal origins; they are not new authorization guards.
D196 leaves `allowed?`, `canonical_origin`, `public_origin` and `preview_origin`
unchanged. Only the existing canonical-tag helper calls `article_canonical_url`.

## Rollout boundary and rollback

Deploy only after approval through the normal Chatwoot release process. Read back
the live pages with the script after any applicable HTML cache refresh. No deploy,
cache purge or production configuration mutation is performed by this script.
To roll back, revert the article canonical selection integration; the previous portal canonicals
return. Keep the membership and tests available for diagnosis.

D191 deliberately leaves the portal sitemap unchanged so crawlers can discover
the pages carrying the canonical tags. Do not remove its URLs as cleanup.
No templates, routes, previews, host authorization, schema, robots rules or website
code change here. The website robots response and its separate content issue
remain with that site's owner. Search Console and Ahrefs observations are separate
from the HTTP receipt; canonical hints do not guarantee which URL ranks.
