class Hm
  # @private
  module Algo
    module_function

    def delete(collection, key)
      collection.is_a?(Array) ? collection.delete_at(key) : collection.delete(key)
    end

    # JRuby, I am looking at you
    NONDUPABLE = [Symbol, Numeric, NilClass, TrueClass, FalseClass].freeze

    def deep_copy(value)
      # FIXME: ignores Struct/OpenStruct (which are diggable too)
      case value
      when Hash
        value.map { |key, val| [key, deep_copy(val)] }.to_h
      when Array
        value.map(&method(:deep_copy))
      when *NONDUPABLE
        value
      else
        value.dup
      end
    end

    # Enumerates through entire collection with "current key/current value" at each point, even
    # if elements are deleted in a process of enumeration
    def robust_enumerator(collection)
      case collection
      when Hash, Struct
        collection.each_pair.to_a
      when Array
        Enumerator.new do |y|
          cur = collection.size
          until cur.zero?
            pos = collection.size - cur
            y << [pos, collection[pos]]
            cur -= 1
          end
        end
      when ->(c) { c.respond_to?(:each_pair) }
        collection.each_pair.to_a
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
      Dig.diggable?(what) or fail TypeError, "#{what.class} is not diggable"

      key, *rst = rest
      if key == WILDCARD
        visit_wildcard(what, rst, path, found: found, not_found: not_found)
      else
        visit_regular(what, key, rst, path, found: found, not_found: not_found)
      end
    end

    def visit_all(what, path = [], &block)
      robust_enumerator(what).each do |key, val|
        yield(what, [*path, key], val)
        visit_all(val, [*path, key], &block) if Dig.diggable?(val)
      end
    end

    def visit_wildcard(what, rest, path, found:, not_found:)
      iterator = robust_enumerator(what)
      if rest.empty?
        iterator.map { |key, val| found.(what, [*path, key], val) }
      else
        iterator.map { |key, el| visit(el, rest, [*path, key], not_found: not_found, &found) }
      end
    end

    def visit_regular(what, key, rest, path, found:, not_found:) # rubocop:disable Metrics/ParameterLists
      internal = Dig.dig(what, key) or return not_found.(what, [*path, key], rest)
      rest.empty? and return found.(what, [*path, key], internal)
      visit(internal, rest, [*path, key], not_found: not_found, &found)
    end
  end
end
