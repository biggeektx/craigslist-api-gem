# Contributing

## Getting set up

```bash
git clone https://github.com/biggeektx/craigslist-api-gem
cd craigslist-api-gem
bin/setup
bundle exec rake
```

`rake` runs the specs and the linter. Both must pass before a pull request can
merge; CI runs them on Ruby 3.3 and 3.4.

## Working on it

- `bundle exec rspec` — specs only
- `bundle exec standardrb --fix` — apply formatting
- `bin/console` — IRB with the gem loaded
- `bundle exec rake doc` — build the YARD docs

## Tests

The suite runs entirely offline. WebMock blocks net connections outright, so a
spec that tries to reach the network fails loudly rather than silently going
out.

There is no VCR. Bulk posting access is granted by Craigslist case by case over
the phone, so there are no credentials to record cassettes with. Response
parsing is tested against fixtures in `spec/fixtures` transcribed from
Craigslist's own published sample documents. When you add coverage for a
response shape, prefer transcribing the documented example over inventing one.

**If you do introduce VCR at some point**, filter request *bodies*, not just
headers. This API puts credentials inside the XML payload
(`<cl:auth username= password=>`), so header-only filtering would commit a
plaintext password to the repository.

## Things worth knowing before you change them

- **Bulk submissions return results, not exceptions.** HTTP status says nothing
  about whether individual postings succeeded, and a batch with some rejections
  is ordinary. Don't "fix" this by raising.
- **A JSON 200 can still be a failure.** The envelope carries an `errors` array
  that must be checked; that is what `APIError` is for.
- **REXML is confined to `Serializer` and `ResponseParser`.** Keep it there so
  the XML library stays swappable.
- **Configuration is frozen and there is no global.** Multi-account use is a
  first-class case; please don't add ambient state.
- **Credentials are redacted from `inspect`.** If you add a class that holds a
  secret, override `inspect` too.

## Pull requests

Keep commits focused and explain *why* in the message rather than restating the
diff. Update `CHANGELOG.md` under `Unreleased` for anything user-facing.

Bug reports and pull requests are welcome at
<https://github.com/biggeektx/craigslist-api-gem>.
