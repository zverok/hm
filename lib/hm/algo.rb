class Hm
  # @private
  module Algo
    module_function

    def delete(collection, key)
      collection.is_a?(Array) ? collection.delete_at(key) : collection.delete(key)
    end

    def deep_copy(collection)
      # FIXME: ignores Struct/OpenStruct (which are diggable too)
      case collection
      when Hash
        collection.map { |key, val| [key, deep_copy(val)] }.to_h
      when Array
        collection.map(&method(:deep_copy))
      else
        collection.dup
      end
    end

    def guess_iterator(collection)
      case
      when collection.respond_to?(:each_pair)
        collection.each_pair.to_a # to_a to avoid "You can't update hash during iteration"
      when collection.respond_to?(:each)
        collection.each_with_index.to_a.map(&:reverse)
      else
        fail TypeError, "Can't dig/* in #{collection.class}"
      end
    end

    def nest_hashes(value, *keys)
      return value if keys.empty?
      key = keys.shift
      val = keys.empty? ? value : nest_hashes(value, *keys)
      key.is_a?(Integer) ? [].tap { |arr| arr[key] = val } : {key => val}
    end

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
  end
end
