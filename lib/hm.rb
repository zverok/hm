class Hm
  WILDCARD = :*

  def initialize(hash)
    @hash = deep_copy(hash)
  end

  def dig(*path)
    visit(@hash, path) { |_, _, val| val }
  end

  def dig!(*path, &not_found)
    not_found ||=
      ->(_, pth, _) { fail KeyError, "Key not found: #{pth.map(&:inspect).join('/')}" }
    visit(@hash, path, not_found: not_found) { |_, _, val| val }
  end

  def bury(*path, value)
    visit(
      @hash, path,
      not_found: ->(at, pth, rest) { at[pth.last] = nest_hashes(value, *rest) }
    ) { |at, pth, _| at[pth.last] = value }
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

  def transform_values(*pathes)
    pathes.each do |path|
      visit(@hash, path) { |at, pth, val| at[pth.last] = yield(val) }
    end
    self
  end

  def transform_keys(*pathes)
    if pathes.empty?
      visit_all(@hash) do |at, path, val|
        if at.is_a?(Hash)
          at.delete(path.last)
          at[yield(path.last)] = val
        end
      end
    else
      pathes.each do |path|
        visit(@hash, path) do |at, pth, val|
          delete(at, pth.last)
          at[yield(pth.last)] = val
        end
      end
    end
    self
  end

  def except(*pathes)
    pathes.each do |path|
      visit(@hash, path) { |what, pth, _| delete(what, pth.last) }
    end
    self
  end

  def slice(*pathes)
    result = Hm.new({})
    pathes.each do |path|
      visit(@hash, path) { |_, new_path, val| result.bury(*new_path, val) }
    end
    @hash = result.to_h
    self
  end

  def compact
    visit_all(@hash) do |at, path, val|
      delete(at, path.last) if val.nil?
    end
  end

  def cleanup
    deletions = -1
    # We do several runs to delete recursively: {a: {b: [nil]}}
    # first: {a: {b: []}}
    # second: {a: {}}
    # third: {}
    # More effective would be some "inside out" visiting, probably
    until deletions.zero?
      deletions = 0
      visit_all(@hash) do |at, path, val|
        if val.nil? || val.respond_to?(:empty?) && val.empty?
          deletions += 1
          delete(at, path.last)
        end
      end
    end
    self
  end

  def select(*pathes)
    res = Hm.new({})
    if pathes.empty?
      visit_all(@hash) do |_, path, val|
        res.bury(*path, val) if yield(path, val)
      end
    else
      pathes.each do |path|
        visit(@hash, path) do |_, pth, val|
          res.bury(*pth, val) if yield(pth, val)
        end
      end
    end
    @hash = res.to_h
    self
  end

  def reject(*pathes)
    if pathes.empty?
      visit_all(@hash) do |at, path, val|
        delete(at, path.last) if yield(path, val)
      end
    else
      pathes.each do |path|
        visit(@hash, path) do |at, pth, val|
          delete(at, pth.last) if yield(pth, val)
        end
      end
    end
    self
  end

  def reduce(keys_to_keys, &block)
    keys_to_keys.each do |from, to|
      bury(*to, dig(*from).reduce(&block))
    end
    self
  end

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

  def visit_all(what, path = [], &block)
    guess_iterator(what).to_a.each do |key, val|
      yield(what, [*path, key], val)
      visit_all(val, [*path, key], &block) if val.respond_to?(:dig)
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

  def transform_one(from, to, remove: true, &_processor) # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/LineLength
    to.count(:*) > 1 || from.count(:*) > 1 and
      fail NotImplementedError, 'Transforming to multi-wildcards is not implemented'

    from_values = {}
    visit(
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

  def guess_iterator(what)
    case
    when what.respond_to?(:each_pair)
      what.each_pair.to_a # to_a to avoid "You can't update hash during iteration"
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

  def delete(what, key)
    what.is_a?(Array) ? what.delete_at(key) : what.delete(key)
  end

  def deep_copy(what)
    # FIXME: ignores Struct/OpenStruct (which are diggable too)
    case what
    when Hash
      what.map { |key, val| [key, deep_copy(val)] }.to_h
    when Array
      what.map(&method(:deep_copy))
    else
      what.dup
    end
  end
end
