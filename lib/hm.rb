class Hm
  WILDCARD = :*

  def initialize(hash)
    # TODO: deep copy before further processing
    @hash = hash
  end

  def dig(*keys)
    visit(@hash, *keys,
      found: ->(_, _, val) { val },
      not_found: ->(*) { }
    )
  end

  def dig!(*keys)
    visit(@hash, *keys,
      found: ->(_, _, val) { val },
      not_found: ->(at, key, *rest) {
        fail KeyError, "Key not found: #{keys[0...-rest.size].map(&:inspect).join('/')}"
      }
    )
  end

  def bury(*keys, value)
    visit(@hash, *keys,
      found: ->(at, key, _) { at[key] = value },
      not_found: ->(at, key, *rest) { at[key] = nest_hashes(value, *rest) }
    )
    self
  end

  def transform(keys_to_keys, &processor)
    keys_to_keys.each { |from, to| transform_one(from, to, &processor) }
    self
  end

  def remove_key(*keys)
    visit(@hash, *keys,
      found: ->(what, key, _) {
        what.is_a?(Array) ? what.delete_at(key) : what.delete(key)
      },
      not_found: ->(*) { }
    )
  end

  def to_h
    @hash
  end

  private

  def visit(what, *keys, found:, not_found:)
    what.respond_to?(:dig) or fail TypeError, "#{what.class} is not diggable"

    k = keys.shift
    if k == WILDCARD
      iterator = guess_iterator(what)
      if keys.empty?
        iterator.map { |key, val| found.(what, key, val) }
      else
        iterator.map { |key, el| visit(el, *keys, found: found, not_found: not_found) }
      end
    else
      internal = what.dig(k) or return not_found.(what, k, *keys)
      keys.empty? and return found.(what, k, internal)
      visit(internal, *keys, found: found, not_found: not_found)
    end
  end

  def transform_one(from, to, &processor)
    to.count(:*) > 1 and raise NotImplementedError, 'Transforming to multi-wildcards is not implemented'

    from_values = {}
    visit(@hash, *from,
      found: ->(at, key, val) { from_values[key] = val },
      # :item, WILDCARD, :price -- one item is priceless, should go to output sequence
      # ...but what if last key is :*? something like from_values.keys.last.succ or?..
      not_found: ->(at, key, *rest) { from_values[rest.last] = nil }
    )
    remove_key(*from)
    if (i = to.index(:*))
      p [from, to, from_values]
      # we unpack [:items, :*, :price] with keys we got from gathering values, like [:items, 0, :price], [:items, 1, :price] etc.
      from_values
        .map { |key, val| [to.dup.tap { |a| a[i] = key }, val] }
        .tap(&method(:p))
        .each { |path, val| bury(*path, val) }
    else
      val = from_values.count == 1 ? from_values.values.first : from_values.values
      bury(*to, val)
    end
  end

  def guess_iterator(what)
    case
    when what.respond_to?(:each_pair)
      what.each_pair
    when what.respond_to?(:each)
      what.each_with_index.to_a.map(&:reverse)
    else
      fail TypeError, "Can't dig/* in #{what.class}"
    end
  end

  def nest_hashes(value, *keys)
    return value if keys.empty?
    k = keys.shift
    keys.empty? ? {k => value} : {k => nest_hashes(value, *keys)}
  end
end
