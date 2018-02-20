# `Hm` is a wrapper for chainable, terse, idiomatic Hash modifications.
#
# @example
#    order = {
#      'items' => {
#        '#1' => {'title' => 'Beef', 'price' => '18.00'},
#        '#2' => {'title' => 'Potato', 'price' => '8.20'}
#      }
#    }
#    Hm(order)
#      .transform_keys(&:to_sym)
#      .transform(%i[items *] => :items)
#      .transform_values(%i[items * price], &:to_f)
#      .reduce(%i[items * price] => :total, &:+)
#      .to_h
#    # => {:items=>[{:title=>"Beef", :price=>18.0}, {:title=>"Potato", :price=>8.2}], :total=>26.2}
#
# @see #Hm
class Hm
  # @private
  WILDCARD = :*

  # @note
  #   `Hm.new(collection)` is also available as top-level method `Hm(collection)`.
  #
  # @param collection Any Ruby collection that has `#dig` method. Note though, that most of
  #   transformations only work with hashes & arrays, while {#dig} is useful for anything diggable.
  def initialize(collection)
    @hash = Algo.deep_copy(collection)
  end

  # Like Ruby's [#dig](https://docs.ruby-lang.org/en/2.4.0/Hash.html#method-i-dig), but supports
  # wildcard key `:*` meaning "each item at this point".
  #
  # Each level of data structure should have `#dig` method, otherwise `TypeError` is raised.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).dig(:items, 0, :title)
  #   # => "Beef"
  #   Hm(order).dig(:items, :*, :title)
  #   # => ["Beef", "Potato"]
  #   Hm(order).dig(:items, 0, :*)
  #   # => ["Beef", 18.0]
  #   Hm(order).dig(:items, :*, :*)
  #   # => [["Beef", 18.0], ["Potato", 8.2]]
  #   Hm(order).dig(:items, 3, :*)
  #   # => nil
  #   Hm(order).dig(:total, :count)
  #   # TypeError: Float is not diggable
  #
  # @param path Array of keys.
  # @return Object found or `nil`,
  def dig(*path)
    Algo.visit(@hash, path) { |_, _, val| val }
  end

  # Like {#dig!} but raises when key at any level is not found. This behavior can be changed by
  # passed block.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).dig!(:items, 0, :title)
  #   # => "Beef"
  #   Hm(order).dig!(:items, 2, :title)
  #   # KeyError: Key not found: :items/2
  #   Hm(order).dig!(:items, 2, :title) { |collection, path, rest|
  #     puts "At #{path}, #{collection} does not have a key #{path.last}. Rest of path: #{rest}";
  #     111
  #   }
  #   # At [:items, 2], [{:title=>"Beef", :price=>18.0}, {:title=>"Potato", :price=>8.2}] does not have a key 2. Rest of path: [:title]
  #   # => 111
  #
  # @param path Array of keys.
  # @yieldparam collection Substructure "inside" which we are currently looking
  # @yieldparam path Path that led us to non-existent value (including current key)
  # @yieldparam rest Rest of the requested path we'd need to look if here would not be a missing value.
  # @return Object found or `nil`,
  def dig!(*path, &not_found)
    not_found ||=
      ->(_, pth, _) { fail KeyError, "Key not found: #{pth.map(&:inspect).join('/')}" }
    Algo.visit(@hash, path, not_found: not_found) { |_, _, val| val }
  end

  # Stores value into deeply nested collection. `path` supports wildcards ("store at each matched
  # path") the same way {#dig} and other methods do. If specified path does not exists, it is
  # created, with a "rule of thumb": if next key is Integer, Array is created, otherwise it is Hash.
  #
  # Caveats:
  #
  # * when `:*`-referred path does not exists, just `:*` key is stored;
  # * as most of transformational methods, `bury` does not created and tested to work with `Struct`.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #
  #   Hm(order).bury(:items, 0, :price, 16.5).to_h
  #   # => {:items=>[{:title=>"Beef", :price=>16.5}, {:title=>"Potato", :price=>8.2}], :total=>26.2}
  #
  #   # with wildcard
  #   Hm(order).bury(:items, :*, :discount, true).to_h
  #   # => {:items=>[{:title=>"Beef", :price=>18.0, :discount=>true}, {:title=>"Potato", :price=>8.2, :discount=>true}], :total=>26.2}
  #
  #   # creating nested structure (note that 0 produces Array item)
  #   Hm(order).bury(:payments, 0, :amount, 20.0).to_h
  #   # => {:items=>[...], :total=>26.2, :payments=>[{:amount=>20.0}]}
  #
  #   # :* in nested insert is not very useful
  #   Hm(order).bury(:payments, :*, :amount, 20.0).to_h
  #   # => {:items=>[...], :total=>26.2, :payments=>{:*=>{:amount=>20.0}}}
  #
  # @param path One key or list of keys leading to the target. `:*` is treated as
  #   each matched subpath.
  # @param value Any value to store at path
  # @return [self]
  def bury(*path, value)
    Algo.visit(
      @hash, path,
      not_found: ->(at, pth, rest) { at[pth.last] = Algo.nest_hashes(value, *rest) }
    ) { |at, pth, _| at[pth.last] = value }
    self
  end

  # Low-level collection walking mechanism.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato"}]}
  #   order.visit(:items, :*, :price,
  #     not_found: ->(at, path, rest) { puts "#{at} at #{path}: nothing here!" }
  #   ) { |at, path, val| puts "#{at} at #{path}: #{val} is here!" }
  #   # {:title=>"Beef", :price=>18.0} at [:items, 0, :price]: 18.0 is here!
  #   # {:title=>"Potato"} at [:items, 1, :price]: nothing here!
  #
  # @param path Path to values to visit, `:*` wildcard is supported.
  # @param not_found [Proc] Optional proc to call when specified path is not found. Params are `collection`
  #   (current sub-collection where key is not found), `path` (current path) and `rest` (the rest
  #   of path we need to walk).
  # @yieldparam collection Current subcollection we are looking at
  # @yieldparam path [Array] Current path we are at (in place of `:*` wildcards there are real
  #   keys).
  # @yieldparam value Current value
  # @return [self]
  def visit(*path, not_found: ->(*) {}, &block)
    Algo.visit(@hash, path, not_found: not_found, &block)
    self
  end

  # Renames input pathes to target pathes, with wildcard support.
  #
  # @note
  #   Currently, only one wildcard per each from and to pattern is supported.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).transform(%i[items * price] => %i[items * price_cents]).to_h
  #   # => {:items=>[{:title=>"Beef", :price_cents=>18.0}, {:title=>"Potato", :price_cents=>8.2}], :total=>26.2}
  #   Hm(order).transform(%i[items * price] => %i[items * price_usd]) { |val| val / 100.0 }.to_h
  #   # => {:items=>[{:title=>"Beef", :price_usd=>0.18}, {:title=>"Potato", :price_usd=>0.082}], :total=>26.2}
  #   Hm(order).transform(%i[items *] => :*).to_h # copying them out
  #   # => {:items=>[], :total=>26.2, 0=>{:title=>"Beef", :price=>18.0}, 1=>{:title=>"Potato", :price=>8.2}}
  #
  # @see #transform_keys
  # @see #transform_values
  # @see #update
  # @param keys_to_keys [Hash] Each key-value pair of input hash represents "source path to take
  #   values" => "target path to store values". Each can be single key or nested path,
  #   including `:*` wildcard.
  # @param processor [Proc] Optional block to process value with while moving.
  # @yieldparam value
  # @return [self]
  def transform(keys_to_keys, &processor)
    keys_to_keys.each { |from, to| transform_one(Array(from), Array(to), &processor) }
    self
  end

  # Like {#transform}, but copies values instead of moving them (original keys/values are preserved).
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).update(%i[items * price] => %i[items * price_usd]) { |val| val / 100.0 }.to_h
  #   # => {:items=>[{:title=>"Beef", :price=>18.0, :price_usd=>0.18}, {:title=>"Potato", :price=>8.2, :price_usd=>0.082}], :total=>26.2}
  #
  # @see #transform_keys
  # @see #transform_values
  # @see #transform
  # @param keys_to_keys [Hash] Each key-value pair of input hash represents "source path to take
  #   values" => "target path to store values". Each can be single key or nested path,
  #   including `:*` wildcard.
  # @param processor [Proc] Optional block to process value with while copying.
  # @yieldparam value
  # @return [self]
  def update(keys_to_keys, &processor)
    keys_to_keys.each { |from, to| transform_one(Array(from), Array(to), remove: false, &processor) }
    self
  end

  # Performs specified transformations on keys of input sequence, optionally limited only by specified
  # pathes.
  #
  # Note that when `pathes` parameter is passed, only keys directly matching the pathes are processed,
  # not entire sub-collection under this path.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).transform_keys(&:to_s).to_h
  #   # => {"items"=>[{"title"=>"Beef", "price"=>18.0}, {"title"=>"Potato", "price"=>8.2}], "total"=>26.2}
  #   Hm(order)
  #     .transform_keys(&:to_s)
  #     .transform_keys(['items', :*, :*], &:capitalize)
  #     .transform_keys(:*, &:upcase).to_h
  #   # => {"ITEMS"=>[{"Title"=>"Beef", "Price"=>18.0}, {"Title"=>"Potato", "Price"=>8.2}], "TOTAL"=>26.2}
  #
  # @see #transform_values
  # @see #transform
  # @param pathes [Array] List of pathes (each being singular key, or array of keys, including
  #   `:*` wildcard) to look at.
  # @yieldparam key [Array] Current key to process.
  # @return [self]
  def transform_keys(*pathes)
    if pathes.empty?
      Algo.visit_all(@hash) do |at, path, val|
        if at.is_a?(Hash)
          at.delete(path.last)
          at[yield(path.last)] = val
        end
      end
    else
      pathes.each do |path|
        Algo.visit(@hash, path) do |at, pth, val|
          Algo.delete(at, pth.last)
          at[yield(pth.last)] = val
        end
      end
    end
    self
  end

  # Performs specified transformations on values of input sequence, limited only by specified
  # pathes.
  #
  # @note
  #   Unlike {#transform_keys}, this method does nothing when no pathes are passed (e.g. not runs
  #   transformation on each value), because the semantic would be unclear. In our `:order` example,
  #   list of all items is a value _too_, at `:items` key, so should it be also transformed?
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).transform_values(%i[items * price], :total, &:to_s).to_h
  #   # => {:items=>[{:title=>"Beef", :price=>"18.0"}, {:title=>"Potato", :price=>"8.2"}], :total=>"26.2"}
  #
  # @see #transform_values
  # @see #transform
  # @param pathes [Array] List of pathes (each being singular key, or array of keys, including
  #   `:*` wildcard) to look at.
  # @yieldparam value [Array] Current value to process.
  # @return [self]
  def transform_values(*pathes)
    pathes.each do |path|
      Algo.visit(@hash, path) { |at, pth, val| at[pth.last] = yield(val) }
    end
    self
  end

  # Removes all specified pathes from input sequence.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).except(%i[items * title]).to_h
  #   # => {:items=>[{:price=>18.0}, {:price=>8.2}], :total=>26.2}
  #   Hm(order).except([:items, 0, :title], :total).to_h
  #   # => {:items=>[{:price=>18.0}, {:title=>"Potato", :price=>8.2}]}
  #
  # @see #slice
  # @param pathes [Array] List of pathes (each being singular key, or array of keys, including
  #   `:*` wildcard) to look at.
  # @return [self]
  def except(*pathes)
    pathes.each do |path|
      Algo.visit(@hash, path) { |what, pth, _| Algo.delete(what, pth.last) }
    end
    self
  end

  # Preserves only specified pathes from input sequence.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).slice(%i[items * title]).to_h
  #   # => {:items=>[{:title=>"Beef"}, {:title=>"Potato"}]}
  #
  # @see #except
  # @param pathes [Array] List of pathes (each being singular key, or array of keys, including
  #   `:*` wildcard) to look at.
  # @return [self]
  def slice(*pathes)
    result = Hm.new({})
    pathes.each do |path|
      Algo.visit(@hash, path) { |_, new_path, val| result.bury(*new_path, val) }
    end
    @hash = result.to_h
    self
  end

  # Removes all `nil` values, including nested structures.
  #
  # @example
  #   order = {items: [{title: "Beef", price: nil}, nil, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).compact.to_h
  #   # => {:items=>[{:title=>"Beef"}, {:title=>"Potato", :price=>8.2}], :total=>26.2}
  #
  # @return [self]
  def compact
    Algo.visit_all(@hash) do |at, path, val|
      Algo.delete(at, path.last) if val.nil?
    end
  end

  # Removes all "empty" values and subcollections (`nil`s, empty strings, hashes and arrays),
  # including nested structures. Empty subcollections are removed recoursively.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.2}, {title: '', price: nil}], total: 26.2}
  #   Hm(order).cleanup.to_h
  #   # => {:items=>[{:title=>"Beef", :price=>18.2}], :total=>26.2}
  #
  # @return [self]
  def cleanup
    deletions = -1
    # We do several runs to delete recursively: {a: {b: [nil]}}
    # first: {a: {b: []}}
    # second: {a: {}}
    # third: {}
    # More effective would be some "inside out" visiting, probably
    until deletions.zero?
      deletions = 0
      Algo.visit_all(@hash) do |at, path, val|
        if val.nil? || val.respond_to?(:empty?) && val.empty?
          deletions += 1
          Algo.delete(at, path.last)
        end
      end
    end
    self
  end

  # Select subset of the collection by provided block (optionally looking only at pathes specified).
  #
  # Method is added mostly for completeness, as filtering out wrong values is better done with
  # {#reject}, and selecting just by subset of keys by {#slice} and {#except}.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).select { |path, val| val.is_a?(Float) }.to_h
  #   # => {:items=>[{:price=>18.0}, {:price=>8.2}], :total=>26.2}
  #   Hm(order).select([:items, :*, :price]) { |path, val| val > 10 }.to_h
  #   # => {:items=>[{:price=>18.0}]}
  #
  # @see #reject
  # @param pathes [Array] List of pathes (each being singular key, or array of keys, including
  #   `:*` wildcard) to look at.
  # @yieldparam path [Array] Current path at which the value is found
  # @yieldparam value Current value
  # @yieldreturn [true, false] Preserve value (with corresponding key) if true.
  # @return [self]
  def select(*pathes)
    res = Hm.new({})
    if pathes.empty?
      Algo.visit_all(@hash) do |_, path, val|
        res.bury(*path, val) if yield(path, val)
      end
    else
      pathes.each do |path|
        Algo.visit(@hash, path) do |_, pth, val|
          res.bury(*pth, val) if yield(pth, val)
        end
      end
    end
    @hash = res.to_h
    self
  end

  # Drops subset of the collection by provided block (optionally looking only at pathes specified).
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}], total: 26.2}
  #   Hm(order).reject { |path, val| val.is_a?(Float) && val < 10 }.to_h
  #   # => {:items=>[{:title=>"Beef", :price=>18.0}, {:title=>"Potato"}], :total=>26.2}
  #   Hm(order).reject(%i[items * price]) { |path, val| val < 10 }.to_h
  #   # => {:items=>[{:title=>"Beef", :price=>18.0}, {:title=>"Potato"}], :total=>26.2}
  #   Hm(order).reject(%i[items *]) { |path, val| val[:price] < 10 }.to_h
  #   # => {:items=>[{:title=>"Beef", :price=>18.0}], :total=>26.2}
  #
  # @see #select
  # @param pathes [Array] List of pathes (each being singular key, or array of keys, including
  #   `:*` wildcard) to look at.
  # @yieldparam path [Array] Current path at which the value is found
  # @yieldparam value Current value
  # @yieldreturn [true, false] Remove value (with corresponding key) if true.
  # @return [self]
  def reject(*pathes)
    if pathes.empty?
      Algo.visit_all(@hash) do |at, path, val|
        Algo.delete(at, path.last) if yield(path, val)
      end
    else
      pathes.each do |path|
        Algo.visit(@hash, path) do |at, pth, val|
          Algo.delete(at, pth.last) if yield(pth, val)
        end
      end
    end
    self
  end

  # Calculates one value from several values at specified pathes, using specified block.
  #
  # @example
  #   order = {items: [{title: "Beef", price: 18.0}, {title: "Potato", price: 8.2}]}
  #   Hm(order).reduce(%i[items * price] => :total, &:+).to_h
  #   # => {:items=>[{:title=>"Beef", :price=>18.0}, {:title=>"Potato", :price=>8.2}], :total=>26.2}
  #   Hm(order).reduce(%i[items * price] => :total, %i[items * title] => :title, &:+).to_h
  #   # => {:items=>[{:title=>"Beef", :price=>18.0}, {:title=>"Potato", :price=>8.2}], :total=>26.2, :title=>"BeefPotato"}
  #
  # @param keys_to_keys [Hash] Each key-value pair of input hash represents "source path to take
  #   values" => "target path to store result of reduce". Each can be single key or nested path,
  #   including `:*` wildcard.
  # @yieldparam memo
  # @yieldparam value
  # @return [self]
  def reduce(keys_to_keys, &block)
    keys_to_keys.each do |from, to|
      bury(*to, dig(*from).reduce(&block))
    end
    self
  end

  # Returns the result of all the processings inside the `Hm` object.
  #
  # Note, that you can pass an Array as a top-level structure to `Hm`, and in this case `to_h` will
  # return the processed Array... Not sure what to do about that currently.
  #
  # @return [Hash]
  def to_h
    @hash
  end

  alias to_hash to_h

  private

  def transform_one(from, to, remove: true, &_processor) # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity
    to.count(:*) > 1 || from.count(:*) > 1 and
      fail NotImplementedError, 'Transforming to multi-wildcards is not implemented'

    from_values = {}
    Algo.visit(
      @hash, from,
      # [:item, :*, :price] -- if one item is priceless, should go to output sequence
      # ...but what if last key is :*? something like from_values.keys.last.succ or?..
      not_found: ->(_, path, rest) { from_values[path + rest] = nil }
    ) { |_, path, val| from_values[path] = block_given? ? yield(val) : val }
    except(from) if remove
    if (ti = to.index(:*))
      fi = from.index(:*) # TODO: what if `from` had no wildcard?

      # we unpack [:items, :*, :price] with keys we got from gathering values,
      # like [:items, 0, :price], [:items, 1, :price] etc.
      from_values
        .map { |key, val| [to.dup.tap { |a| a[ti] = key[fi] }, val] }
        .each { |path, val| bury(*path, val) }
    else
      val = from_values.count == 1 ? from_values.values.first : from_values.values
      bury(*to, val)
    end
  end
end

require_relative 'hm/algo'
require_relative 'patch/dig'

# Shortcut for {Hm}.new
def Hm(hash) # rubocop:disable Naming/MethodName
  Hm.new(hash)
end
