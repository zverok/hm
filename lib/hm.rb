class Hm
  WILDCARD = :*

  def initialize(hash)
    @hash = Algo.deep_copy(hash)
  end

  def dig(*path)
    Algo.visit(@hash, path) { |_, _, val| val }
  end

  def dig!(*path, &not_found)
    not_found ||=
      ->(_, pth, _) { fail KeyError, "Key not found: #{pth.map(&:inspect).join('/')}" }
    Algo.visit(@hash, path, not_found: not_found) { |_, _, val| val }
  end

  def bury(*path, value)
    Algo.visit(
      @hash, path,
      not_found: ->(at, pth, rest) { at[pth.last] = Algo.nest_hashes(value, *rest) }
    ) { |at, pth, _| at[pth.last] = value }
    self
  end

  def visit(*path, not_found: ->(*) {}, &block)
    Algo.visit(@hash, path, not_found: not_found, &block)
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
      Algo.visit(@hash, path) { |at, pth, val| at[pth.last] = yield(val) }
    end
    self
  end

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

  def except(*pathes)
    pathes.each do |path|
      Algo.visit(@hash, path) { |what, pth, _| Algo.delete(what, pth.last) }
    end
    self
  end

  def slice(*pathes)
    result = Hm.new({})
    pathes.each do |path|
      Algo.visit(@hash, path) { |_, new_path, val| result.bury(*new_path, val) }
    end
    @hash = result.to_h
    self
  end

  def compact
    Algo.visit_all(@hash) do |at, path, val|
      Algo.delete(at, path.last) if val.nil?
    end
  end

  def cleanup
    deletions = -1
    # We do several runs to delete recursively: {a: {b: [nil]}}
    # first: {a: {b: []}}
    # second: {a: {}}
    # third: {}
    # More effective would be some "inside out" Algo.visiting, probably
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

  def transform_one(from, to, remove: true, &_processor) # rubocop:disable Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/LineLength
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
