**Hm** is an experimental Ruby gem trying to provide effective, idiomatic, chainable hash
transformations DSL.

## Components

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

Chainable transformations:

* bury
* rename_keys
* except_keys (also `except`) `Hm(order).except(:items, :*, :id).to_h # =>`
* reject_values
* reduce(%i[order items * price] => :total, &:+)
* remap(%i[order items * price] => %i[order items * price_usd]) { |val| val / 100 }
* transform_keys ? or deep ?
* transform_values

For really deep transformations, there is `in(*path)` operators:

Structure control:

* expect(:foo, :bar)
* expect_match(:foo, :bar, Array)
* expect_match(:bar, :baz, :*, Integer)
* ^ +rspec expect_match(:bar, :baz, :*, Hm.hash_including(:))

Regular hash methods are also supported:

Transformational (means it returns the `Hm` object back):

* merge
* transform_keys
* transform_values
* slice
* select
* reject
* compact

Final (returns what is at the first keys):

* fetch

## Packing and operations

`Hm()` can be saved to variable, and applied:

```ruby
WEATHER_TRANSFORM = Hm()
  .rename(%w[temp min] => :temp_min, %w[temp max] => :temp_max)
  .transform_values(:dt, &Time.method(:at))

weathers.map(&WEATHER_TRANSFORM)
```

## Prior art

Hash transformers:

* https://github.com/solnic/transproc
* https://github.com/deseretbook/hashformer

Hash pathes:

## Author
