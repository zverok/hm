# Hm? Hm!

**Hm** is an experimental Ruby gem trying to provide effective, idiomatic, chainable **H**ash
**m**odifications (transformations) DSL.

## Showcase

```ruby
api_json = <<-JSON
{
  "coord": {"lon": -0.13, "lat": 51.51},
  "weather": [{"id": 300, "main": "Drizzle", "description": "light intensity drizzle", "icon": "09d"}],
  "base": "stations",
  "main": {"temp": 280.32, "pressure": 1012, "humidity": 81, "temp_min": 279.15, "temp_max": 281.15},
  "visibility": 10000,
  "wind": {"speed": 4.1, "deg": 80},
  "clouds": {"all": 90},
  "dt": 1485789600,
  "sys": {"type": 1, "id": 5091, "message": 0.0103, "country": "GB", "sunrise": 1485762037, "sunset": 1485794875},
  "id": 2643743,
  "name": "London",
  "cod": 200
}
JSON

weather = JSON.parse(api_json)
pp Hm.new(weather)
  .transform_keys(&:to_sym)                         # symbolize all keys
  .except(:id, :cod, %i[sys id], %i[weather * id])  # remove some system values
  .transform(
    %i[main *] => :*,                               # move all {main: {temp: X}} to just {temp: X}
    %i[sys *] => :*,                                # same for :sys
    %i[coord *] => :coord,                          # gather values for coord.lat, coord.lng into Array in :coord
    [:weather, 0] => :weather,                      # move first of :weather Array to just :weather key
    dt: :timestamp                                  # rename :dt to :timestamp
  )
  .cleanup                                          # remove now empty main: {} and sys: {} hashes
  .transform_values(
    :timestamp, :sunrise, :sunset,
    &Time.method(:at))                              # parse timestamps
  .bury(:weather, :comment, 'BAD')                  # insert some random new key
  .to_h
# {
#  :coord=>[-0.13, 51.51],
#  :weather=> {:main=>"Drizzle", :description=>"light intensity drizzle", :icon=>"09d", :comment=>"BAD"},
#  :base=>"stations",
#  :visibility=>10000,
#  :wind=>{:speed=>4.1, :deg=>80},
#  :clouds=>{:all=>90},
#  :name=>"London",
#  :temp=>280.32,
#  :pressure=>1012,
#  :humidity=>81,
#  :temp_min=>279.15,
#  :temp_max=>281.15,
#  :type=>1,
#  :message=>0.0103,
#  :country=>"GB",
#  :sunrise=>2017-01-30 09:40:37 +0200,
#  :sunset=>2017-01-30 18:47:55 +0200,
#  :timestamp=>2017-01-30 17:20:00 +0200}
# }
```

## Features/problems

* Small, no-dependencies, no-monkeypatching, just "plug and play";
* Idiomatic, terse, chainable;
* Very new and exprimental, works on the cases I've extracted from different production problems and
  invented on the road, but may not work for yours;
* Most of methods work on Arrays and Hashes, but not on `Struct` and `OpenStruct` (which are
  `dig`-able in Ruby), though, base `#dig` and `#dig!` should work on them too;
* API is subject to polish and change in future.

## Usage

Install it with `gem install hm` or adding `gem 'hm'` in your `Gemfile`.

One of the most important concepts of `Hm` is "path" through the structure. It is the same list of
keys Ruby's native `#dig()` supports, with one, yet powerful, addition: `:*` stands for `each` (works
with any `Enumerable` that is met at structure at this point):

```ruby
order = {
  date: Date.today,
  items: [
    {title: 'Beer', price: 10.0},
    {title: 'Beef', price: 5.0},
    {title: 'Potato', price: 7.8}
  ]
}
Hm(order).dig(:items, :*, :price) # => [10.0, 5.0, 7.8]
```

On top of that, `Hm` provides a set of chainable transformations, which can be used this way:

```ruby
Hm(some_hash)
  .transformation(...)
  .transformation(...)
  .transformation(...)
  .to_h # => return the processed hash
```

List of currently available transformations:

* `bury(:key1, :key2, :key3, value)` — opposite to `dig`, stores value in a nested structure;
* `transform([:path, :to, :key] => [:other, :path], [:multiple, :*, :values] => [:other, :*])` —
  powerful key renaming, with wildcards support;
* `transform_keys(path, path, path) { |key| ... }` — works with nested hashes (so you can just
  `transform_keys(&:to_sym)` to deep symbolize keys), and is able to limit processing to only
  specified pathes, like `transform_keys([:order, :items, :*, :*], &:capitalize)`
* `transform_values(path, path, path) { |key| ... }`
* `update` — same as `transform`, but copies source key to target ones, instead of moving;
* `slice(:key1, :key2, [:path, :to, :*, :key3])` — extracts only list of specified key pathes;
* `except(:key1, :key2, [:path, :to, :*, :key3])` — removes list of specified key pathes;
* `compact` removes all `nil` values, including nested collections;
* `cleanup` recursively removes all "empty" values (empty strings, hashes, arrays, `nil`s);
* `select(path, path) { |val| ... }` — selects only parts of hash that match specified pathes and
  specified block;
* `reject(path, path) { |val| ... }` — drops parts of hash that match specified pathes and
  specified block;
* `reduce([:path, :to, :*, :values] => [:path, :to, :result]) { |memo, val| ... }` — reduce several
  values into one, like `reduce(%i[items * price] => :total, &:+)`.

Look at [API docs](http://www.rubydoc.info/gems/hm) for details about each method.

## Further goals

Currently, I am planning to just use existing one in several projects and see how it will go. The
ideas to where it can be developed further exist, though:

* Just add more useful methods (like `merge` probably), and make their addition modular;
* There is a temptation for more powerful "dig path language", I am looking for a real non-imaginary
   cases for those, theoretically pretty enchancements:
  * `:**` for arbitrary depth;
  * `/foo/` and `(0..1)` for selecting key ranges;
  * `[:weather, [:sunrise, :sunset]]` for selecting `weather.sunrise` AND `weather.sunset` path;
  * `[:items, {title: 'Potato'}]` for selecting whole hashes from `:items`, which have `title: 'Potato'`
    in them.
* `Hm()` idiom for storing necessary transformations in constants:

```ruby
WEATHER_TRANSFORM = Hm()
  .tranform(%w[temp min] => :temp_min, %w[temp max] => :temp_max)
  .transform_values(:dt, &Time.method(:at))

# ...later...
weathers.map(&WEATHER_TRANSFORM)
```
* "Inline expectations framework":

```ruby
Hm(api_response)
  .expect(:results, 0, :id) # raises if api_response[:results][0][:id] is absent
  .transform(something, something) # continue with our tranformations
```

If you find something of the above useful for production use-cases, drop me a note (or GitHub issue;
or, even better, PR!).

## Prior art

Hash transformers:

* https://github.com/solnic/transproc
* https://github.com/deseretbook/hashformer

Hash pathes:

* https://github.com/nickcharlton/keypath-ruby
* https://github.com/maiha/hash-path

## Author

[Victor Shepelev aka @zverok](https://zverok.github.io)

## License

MIT
