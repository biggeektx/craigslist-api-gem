# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the version is below 1.0.0 the public API may change between minor
versions. The gem wraps an API that cannot be exercised without access granted
by Craigslist, so real-world use may surface corrections.

## [Unreleased]

## [0.1.0] - 2026-08-19

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

### Verification

Exercised end to end against a live bulk posting account: five postings created
and removed in `pit`/`ctd`, plus validation, status, body, price, image upload
and reordering, delete/undelete, billing, and error mapping. Two corrections
came out of that run and are folded in above -- the zip lookup payload shape,
and the missing subarea in the documented example.

The offline suite is 207 examples with no network access; response parsing is
checked against fixtures transcribed from craigslist's published samples.

### Known limitations

- Requires a craigslist account granted bulk posting access, which is arranged
  case by case and limited to paid US categories.
- Postings are created through the RSS interface and managed through the JSON
  API; neither can do the other's job, which is why one client fronts both.
- `Serializer` builds the request as a DOM. Batches carrying many base64 images
  are held in memory whole; submit in modest batches until that is revisited.

[Unreleased]: https://github.com/biggeektx/craigslist-api-gem/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/biggeektx/craigslist-api-gem/releases/tag/v0.1.0
