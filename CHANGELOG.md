# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the version is below 1.0.0 the public API may change between minor
versions. The gem wraps an API that cannot be exercised without access granted
by Craigslist, so real-world use may surface corrections.

## [Unreleased]

## [0.1.0] - 2026-08-17

Initial release.

### Added

- `Craigslist::API::Client`, a single client covering both halves of the bulk
  posting platform: the RSS interface used to create postings and the JSON
  Bulkpost API used to manage them afterwards.
- Posting creation via `#validate` and `#post`, returning a `ResultSet` of
  per-posting outcomes rather than raising, since a bulk submission succeeds
  and fails per item.
- `Posting` and `Image` models with local validation, covering the newer flat
  attribute groups (`housing_basics`, `job_basics`, `auto_basics`, `forsale`,
  `generic`, `housing_terms`, `housing_pets`) and `brokerInfo`.
- `PostingHandle` for live postings, via `client.posting(id)`: status, body,
  price, remuneration, delete/undelete, images, and statistics.
- Resource groups for postings, images, billing, and account.
- Areas and categories from the public reference service, memoized per client.
- OAuth2 client credentials flow with automatic token caching and refresh,
  including a single retry on a 401.
- Value objects for `Money`, `CreditSummary`, `PostingBlock`, `PostingStats`,
  `ImageInfo`, `Area`, and `Category`.
- An error hierarchy rooted at `Craigslist::API::Error`, including `APIError`
  for the case where an HTTP 200 carries a populated `errors` array.
- `ZipLocation`, returned by `#area_for_zip`. Carries the subarea, which a
  flat return value would discard -- and a missing subarea is the most common
  cause of a `NOT_VALID` posting. `#to_h` splats straight into `Posting.new`.
- `ResultSet#raw`, the unparsed response body, so an unexplained rejection can
  be inspected without rebuilding the request by hand.

### Notes

Verified against a live bulk posting account: postings created and removed in
`pit`/`ctd`, plus management, billing, image and error paths. Two corrections
came out of that run, both folded in above -- the zip lookup shape, and the
missing subarea in the smoke-test example.

[Unreleased]: https://github.com/biggeektx/craigslist-api-gem/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/biggeektx/craigslist-api-gem/releases/tag/v0.1.0
