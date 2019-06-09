class Hm
  # @private
  module Dig
    # TODO: Struct/OpenStruct are also diggable in Ruby core, can be added for future implementation
    DIGGABLE_CLASSES = [Hash, Array].freeze
    NotFound = Object.new.freeze

    def self.dig(what, key, *keys)
      # We want to return special value when key is not present, because
      # 1. "at some point in path, we have a value, and this value is `nil`", and
      # 2. "at some point in path, we don't have a value (key is absent)"
      # ...should be different in Algo.visit
      return NotFound unless key?(what, key)

      return what.dig(key, *keys) if what.respond_to?(:dig)

      ensure_diggable?(what) or fail TypeError, "#{value.class} is not diggable"
      value = what[key]
      keys.empty? ? value : dig(value, *keys)
    end

    def self.key?(what, key)
      case what
      when Array
        (0...what.size).cover?(key)
      when Hash
        what.key?(key)
      end
    end

    def self.diggable?(what)
      DIGGABLE_CLASSES.include?(what.class)
    end
  end
end
