class Hm
  WILDCARD = :*

  def initialize(hash)
    # TODO: deep copy before further processing
    @hash = hash
  end

  def dig(*keys)
    visit(@hash, keys) { |_, _, val| val }
  end

  def dig!(*keys)
    visit(
      @hash, keys,
      not_found: ->(_, path, _) {
        fail KeyError, "Key not found: #{path.map(&:inspect).join('/')}"
      }
    ) { |_, _, val| val }
  end

  def bury(*keys, value)
    visit(
      @hash, keys,
      not_found: ->(at, path, rest) { at[path.last] = nest_hashes(value, *rest) }
    ) { |at, path, _| at[path.last] = value }
    self
  end

  def transform(keys_to_keys, &processor)
    keys_to_keys.each { |from, to| transform_one(Array(from), Array(to), &processor) }
    self
  end

  def update(keys_to_keys, &processor)
    keys_to_keys.each { |from, to| transform_one(Array(from), Array(to), remove: false, &processor) }
    self
  end

  def transform_values(*keys)
    keys.each do |ks|
      visit(@hash, ks) { |at, path, val| at[path.last] = yield(val) }
    end
    self
  end

  def reject_keys(*keys)
    keys.each(&method(:reject_one))
    self
  end

  alias except reject_keys

  def to_h
    @hash
  end

  private

  def visit(what, rest, path = [], not_found: ->(*) {}, &found)
    what.respond_to?(:dig) or fail TypeError, "#{what.class} is not diggable"

    key, *rst = rest
    if key == WILDCARD
      visit_wildcard(what, rst, path, found: found, not_found: not_found)
    else
      visit_regular(what, key, rst, path, found: found, not_found: not_found)
    end
  end

  def visit_wildcard(what, rest, path, found:, not_found:)
    iterator = guess_iterator(what)
    if rest.empty?
      iterator.map { |key, val| found.(what, [*path, key], val) }
    else
      iterator.map { |key, el| visit(el, rest, [*path, key], not_found: not_found, &found) }
    end
  end

  def visit_regular(what, key, rest, path, found:, not_found:) # rubocop:disable Metrics/ParameterLists
    internal = what.dig(key) or return not_found.(what, [*path, key], rest)
    rest.empty? and return found.(what, [*path, key], internal)
    visit(internal, rest, [*path, key], not_found: not_found, &found)
  end

  def reject_one(keys)
    visit(@hash, keys) do |what, path, _|
      what.is_a?(Array) ? what.delete_at(path.last) : what.delete(path.last)
    end
    self
  end

  def transform_one(from, to, remove: true, &_processor) # rubocop:disable Metrics/AbcSize
    to.count(:*) > 1 || from.count(:*) > 1 and
      fail NotImplementedError, 'Transforming to multi-wildcards is not implemented'

    from_values = {}
    visit(
      @hash, from,
      # [:item, :*, :price] -- if one item is priceless, should go to output sequence
      # ...but what if last key is :*? something like from_values.keys.last.succ or?..
      not_found: ->(_, path, rest) { from_values[path + rest] = nil }
    ) { |_, path, val| from_values[path] = block_given? ? yield(val) : val }
    reject_one(from) if remove
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
    key = keys.shift
    val = keys.empty? ? value : nest_hashes(value, *keys)
    key.is_a?(Integer) ? [].tap { |arr| arr[key] = val } : {key => val}
  end
end
