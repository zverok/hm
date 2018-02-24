class Hm
  # @private
  module Dig
    # TODO: Struct/OpenStruct are also diggable in Ruby core, can be added for future implementation
    DIGGABLE_CLASSES = [Hash, Array].freeze

    def self.dig(what, *keys)
      return what.dig(*keys) if what.respond_to?(:dig)

      if diggable?(what) or fail TypeError, "#{value.class} is not diggable"
        value = what[keys.shift]
        (value.nil? || keys.empty?) ? value : dig(value, *keys)
      end
    end

    def self.diggable?(what)
      DIGGABLE_CLASSES.include?(what.class)
    end
  end
end
