# craigslist-api

[![CI](https://github.com/biggeektx/craigslist-api-gem/actions/workflows/ci.yml/badge.svg)](https://github.com/biggeektx/craigslist-api-gem/actions/workflows/ci.yml)

A Ruby client for Craigslist's bulk posting platform.

Craigslist splits this platform across two services that look nothing alike:

| | Creating postings | Managing them afterwards |
|---|---|---|
| Service | `post.craigslist.org/bulk-rss` | `bapi.craigslist.org/bulkpost/v1` |
| Format | RDF/RSS XML | JSON (writes are form-encoded) |
| Auth | credentials inside the XML body | OAuth2 bearer token |

One set of credentials covers both, and neither can do the other's job — you
cannot create a posting over the JSON API, and you cannot edit one over RSS.
This gem hides that seam behind a single client.

```ruby
client  = Craigslist::API.new(email: ..., password: ..., account_id: ...)
results = client.post(postings)          # RSS under the hood
client.posting(results.posting_ids.first).price = 4200   # JSON under the hood
```

## Before you start

**Bulk posting access is not self-serve.** Craigslist grants it case by case to
high-volume posters (hundreds of postings per month), and only for paid US
categories: jobs (offered), apartment rentals in NYC, and for-sale-by-dealer.
Contact them at 415-399-5200 x8283.

Without a granted account, every call in this README will return HTTP 403.

## Installation

```ruby
gem "craigslist-api"
```

Then `bundle install`. Requires Ruby 3.3 or newer.

## Quick start

```ruby
require "craigslist/api"

client = Craigslist::API.new(
  email:      "you@example.com",
  password:   ENV.fetch("CRAIGSLIST_PASSWORD"),
  account_id: 1234
)

posting = Craigslist::API::Posting.new(
  key:         "listing-1",              # your own identifier for this posting
  title:       "1998 Toyota Hilux",
  description: "Runs great. Highway miles.",
  category:    "ctd",                    # cars & trucks - by dealer
  area:        "sfo",
  price:       4500,
  reply_email: "sales@example.com",
  location:    {postal: "94110"}
)

# Dry run first. This sends the identical document that #post would.
check = client.validate(posting)
abort check.failed.map(&:explanation).join("\n") if check.any_failures?

results = client.post(posting)
results.posting_ids  #=> ["7123456780"]
```

## Creating postings

### Results, not exceptions

A bulk submission succeeds and fails *per posting*, and the HTTP status tells
you nothing about it — a 200 can carry a document in which every posting
failed. So `#post` and `#validate` return a `ResultSet` rather than raising.
A batch with a few rejections is ordinary, not exceptional.

```ruby
results = client.post(postings)

results.all_successful?   #=> false
results.successful        #=> [Result, ...]
results.failed            #=> [Result, ...]
results.posting_ids       #=> ids of postings that were created
results.upload_id         #=> craigslist's id for the whole batch
results["listing-1"]      #=> the Result for the key you submitted

results.failed.each do |result|
  warn "#{result.key}: #{result.status} — #{result.explanation}"
end
```

Transport and authentication failures *do* raise. See [Errors](#errors).

Each `Result` answers the status it came back with:

| Predicate | Status | Meaning |
|---|---|---|
| `valid?` | `VALID` | passed validation (validate mode only) |
| `posted?` | `POSTED` | accepted (post mode only) |
| `not_valid?` | `NOT_VALID` | rejected; see `explanation` |
| `insufficient_blocks?` | `INSUFFICIENT_BLOCKS` | out of prepaid blocks for this area/category |
| `credit_limit_reached?` | `CREDIT_LIMIT_REACHED` | invoiced account hit its limit |
| `credit_card_error?` | `CREDIT_CARD_ERROR` | card could not be billed |
| — | `FAILED` | unexpected error at post time |

`success?` covers `VALID` and `POSTED`; `failure?` is everything else.

### Don't skip the warnings

Craigslist returns non-fatal warnings — usually XML it had to paper over —
**alongside successes**, which makes them easy to miss entirely:

```ruby
results.warned.each do |result|
  warn "#{result.key} posted with warnings: #{result.warnings.join(", ")}"
end
```

### Posting fields

Only `key`, `title`, `description`, `category`, `area` and a location are
required. A location means either `:postal`, or both `:latitude` and
`:longitude`.

```ruby
Craigslist::API::Posting.new(
  key:                "listing-2",
  title:              "1BR in Chelsea",
  description:        "Sunny, quiet block.",
  category:           "apa",
  area:               "nyc",
  subarea:            "mnh",             # required where an area has subareas
  neighborhood:       "Chelsea",
  price:              4875,
  po_number:          "PO-094122",       # your own tracking reference
  reply_email:        "leasing@example.com",
  reply_privacy:      :anonymous,        # :none | :anonymous | :public
  other_contact_info: "212.555.1212",

  location: {
    postal: "10011", city: "New York", state: "NY",
    cross_street1: "23rd Street", cross_street2: "9th Avenue",
    latitude: 40.746492, longitude: -74.001326
  },

  housing_basics: {bedrooms: 1, bathrooms: 1, surface_area: 850,
                   housing_type: "apartment", laundry: "w/d in unit",
                   is_furnished: false},
  housing_terms:  {rent_period: "monthly", broker_fee: true},
  housing_pets:   {pets_cat: true, pets_dog: false},
  broker:         {company_name: "Sample & Associates", fee_disclosure: "One month"},

  images: ["photos/living-room.jpg", "photos/kitchen.jpg"]
)
```

Booleans are written as the `0`/`1` the interface expects — pass `true`/`false`
and the gem translates.

The attribute groups map straight onto the interface's newer flat field sets:
`generic`, `housing_basics`, `housing_pets`, `housing_terms`, `job_basics`,
`auto_basics`, `forsale`, plus `broker` for `cl:brokerInfo`. Their keys pass
through unchanged, so anything Craigslist documents for a group works without
this gem needing to know about it.

Postings are validated on construction and raise `ValidationError` listing
*every* problem, not just the first:

```ruby
Craigslist::API::Posting.new(key: "x", title: "", description: "b",
                             category: "", area: "sfo", location: {})
# => Craigslist::API::ValidationError:
#      title is required; category is required;
#      location requires :postal, or both :latitude and :longitude
```

### Images

Up to 24 per posting, sent inline as base64. Position is zero-based and
position 0 is the image featured on search pages.

```ruby
images: [
  "photos/front.jpg",                                    # path
  Pathname("photos/side.jpg"),                           # Pathname
  File.open("photos/rear.jpg", "rb"),                    # any IO
  Craigslist::API::Image.from_base64(encoded, position: 5)
]
```

Positions are assigned in order when you don't set them. Raw base64 must go
through `Image.from_base64` — guessing whether a String is a path or a payload
would be worse than asking.

> Bulk submissions with many images get large fast: 24 images at 200KB each is
> roughly 6MB of base64 *per posting*. Submit in modest batches.

## Managing live postings

`client.posting(id)` returns a handle. It caches nothing, so it can never go
stale:

```ruby
posting = client.posting("7123456780")

posting.status              #=> "active" | "deleted" | "expired" | "pending" | "removed"
posting.active?             #=> true

posting.body                #=> "The posting body"
posting.body = "New text"
posting.price = 4200
posting.remuneration = "$19.95/hr plus tips"   # jobs and gigs

posting.images              #=> [ImageInfo, ...]
posting.add_image("new.jpg")
posting.add_image("hero.jpg", insert_position: 0)
posting.reorder_images(%w[4:00202_x 4:00101_y])
posting.remove_image("4:00101_y")

posting.stats.total_views   #=> 1_284

posting.delete
posting.undelete
```

Two API quirks worth knowing: postings in `ctd` (cars & trucks by dealer) must
keep the VIN they were created with, and removing an image only *detaches* it —
the image itself stays publicly retrievable.

The same operations are available grouped by resource if you prefer:
`client.postings`, `client.images`, `client.billing`, `client.account`.

## Billing, stats, and reference data

```ruby
credit = client.credit
credit.remaining.to_s              #=> "3.00 USD"
credit.remaining.to_f              #=> 3.0

client.posting_blocks.each do |block|
  puts "#{block.area} #{block.product_class}: #{block.remaining_posts} left"
end

client.pricing(area: "sfo", category: "ofc").to_s   #=> "1000.00 USD"
client.billing.create_invoice                       #=> ["1234321"]

client.area_for_zip("02134")       #=> {abbreviation: "bos", description: "boston"}
```

Money keeps Craigslist's minor-unit representation and converts through
`Rational`, so scaling is exact.

Statistics cover a rolling 30-day window ending midnight UTC yesterday, and
count requests rather than unique viewers:

```ruby
stats = client.stats(start: "2026-01-01", stop: "2026-01-31")

stats.each do |posting|
  puts "#{posting.posting_id}: #{posting.total_views} views, #{posting.total_contact} contacts"
end

stats.first[:impressions]   #=> [[2026-01-01 00:00:00 UTC, 57], ...]
```

Metrics: `impressions`, `views`, `contact`, `contact_chat`, `contact_phone`,
`contact_email`, `share`, `favorite`.

Areas and categories come from Craigslist's public reference service (no auth
needed) and are memoized per client:

```ruby
client.reference.area("sfo").subareas.map(&:abbreviation)  #=> ["sfc", "sby", ...]
client.reference.area("sfo").subareas?                     #=> true
client.reference.category("ctd").description               #=> "cars & trucks - by dealer"
client.reference.category("prk").unsupported?              #=> true
```

### Account messages

Craigslist attaches notices to every JSON response and repeats them until
acknowledged. Surface them somewhere a human will look:

```ruby
client.account_messages.each do |message|
  logger.info("craigslist: #{message["message"]}")
  client.account.acknowledge(message["messageId"])
end
```

## Errors

Everything raised derives from `Craigslist::API::Error`.

```
Error
├── ConfigurationError    missing or blank credentials
├── ValidationError       caught locally, before any request; carries #errors
├── ConnectionError       DNS, refused, TLS
│   └── TimeoutError
├── ParseError            response was not the XML/JSON it promised
└── ResponseError         carries #status, #body, #api_errors
    ├── RequestError            400, or 415 for unparseable RSS
    ├── AuthenticationError     401/403, or a rejected token
    ├── NotFoundError           404
    ├── RateLimitError          429
    ├── ServerError             5xx
    └── APIError                HTTP 200 with a populated errors array
```

`APIError` exists because the JSON API reports application-level failures
in-band. A 200 is not proof of success:

```ruby
begin
  client.posting("7123456780").body = "updated"
rescue Craigslist::API::APIError => e
  e.api_errors  #=> [{"code" => 0, "message" => "posting 7123456780 not found"}]
end
```

## Configuration

```ruby
Craigslist::API.new(
  email:      "you@example.com",
  password:   ENV.fetch("CRAIGSLIST_PASSWORD"),
  account_id: 1234,

  timeout:      120,          # read timeout; generous, submissions can be large
  open_timeout: 15,
  logger:       Rails.logger, # logs request lines via Faraday
  adapter:      :net_http,    # any Faraday adapter
  scopes:       %w[bulkpost.posting bulkpost.account.billing],
  user_agent:   "my-app/1.0"
)
```

Scopes are hierarchical — `bulkpost.posting` grants `bulkpost.posting.delete`
and the rest beneath it. The default requests all four top-level scopes.

### Threads and multiple accounts

Configuration is frozen and nothing mutates at request time, so a client is
safe to share across threads. The OAuth token is cached per client behind a
mutex and refreshed automatically, including once on a 401 in case it was
revoked early.

There is no global to configure. Talking to several accounts means building
several clients, which is deliberate — ambient credentials are exactly the
thing that breaks when one process serves more than one account.

```ruby
CLIENTS = accounts.to_h { |a| [a.id, Craigslist::API.new(**a.credentials)] }
```

Passwords and tokens are redacted from `inspect` output, so a stray `inspect`
in a log line or exception backtrace will not leak them.

## Development

```bash
bin/setup           # install dependencies
bundle exec rake    # specs + linter
bundle exec rspec
bundle exec standardrb --fix
bin/console         # IRB with the gem loaded
```

The suite is fully offline — WebMock blocks net connections outright. Response
parsing is tested against fixtures transcribed from Craigslist's own published
samples.

## Contributing

Bug reports and pull requests are welcome at
<https://github.com/biggeektx/craigslist-api-gem>.

## License

Released under the [MIT License](LICENSE.txt).
