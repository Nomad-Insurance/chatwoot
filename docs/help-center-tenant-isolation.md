# Help Center tenant isolation deployment

No database migration is required. Deploy the Rails changes and rebuilt dashboard assets together. No production records are changed by this patch.

## Required hostname records

Ensure these `account_domains` records exist and have the correct owners:

| host | account_id |
| --- | --- |
| portal.nomadinsurance.com | The actual Nomad account ID (verify; do not assume it is 1) |
| portal.expatinsurance.com | 2 |

The active portal with slug `expat-insurance-helpdesk` must belong to account 2. It can keep `custom_domain` unset: its AccountDomain mapping authorizes Expat's hostname and makes it canonical when it is that account's only eligible hostname.

Keep `FRONTEND_URL=https://portal.nomadinsurance.com`. It cannot override either hostname's account mapping. `HELPCENTER_URL` can stay empty. If a neutral shared Help Center is wanted, explicitly configure its full origin in `HELPCENTER_URL`, provision DNS/TLS, and do not assign that hostname to an AccountDomain or portal custom domain. Legacy unmapped FRONTEND_URL hosts still serve public pages for shared installations, but are never an implicit preview fallback.

An explicit portal custom domain is preferred for canonical and preview URLs. It may only serve that portal. AccountDomain ownership wins if records conflict; fix conflicting configuration rather than relying on a custom domain to override account ownership.

## Public URLs and redirects

Every public Help Center route checks the requested active portal against the host before branding, locale lookup, content or tracking. Public article lookup requires published status.

Old cross-host HTML portal, category and published article URLs receive a 301 only when the destination is unambiguous: an authorized explicit custom domain, or exactly one eligible AccountDomain hostname. With multiple account hostnames and no custom domain, mismatches return 404. Missing content, draft/archived articles, previews, search, JSON, Markdown, sitemap and tracking mismatches return 404. Redirects discard query parameters.

Canonical tags omit query parameters and prefer the canonical tenant origin. Sitemap article URLs use the same origin. When several account hostnames are valid but none is canonical, accepted pages use the neutral shared Help Center origin if configured, otherwise their current authorized origin.

## Draft previews

The dashboard calls the existing account-scoped Articles API's new `POST .../articles/:id/preview` action. Administrator authorization (including Enterprise knowledge-base management permission) is required. Host selection is:

1. The portal's authorized custom domain.
2. The current hostname if AccountForHost maps it to the portal's account and the portal is allowed there.
3. An explicitly configured neutral HELPCENTER_URL.

If no host qualifies, the API returns 422 and the dashboard displays its existing error message.

The API issues a Rails signed article ID expiring after 15 minutes, bound to the portal and selected hostname. The dashboard opens `/hc/:slug/articles/:article_slug/preview?preview_token=...`. Ordinary public article URLs ignore preview authorization and still require publication. Archiving a portal immediately disables previews. Tokens are bearer links: anyone receiving a valid link can view that article until expiry; keep them private.

Preview responses are no-store, noindex/nofollow and no-referrer, omit canonical tags and view tracking. Rails already filters token parameters. Configure reverse proxies/CDNs/access logging to redact `preview_token`, honor no-store, and never cache preview routes. All application instances must share the existing Rails signing secret. Purge previously cached Help Center HTML/Markdown at rollout, especially any draft/archived pages cached before this fix. No automatic CDN purge or production configuration changes are performed here.
