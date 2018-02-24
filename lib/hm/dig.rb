class Hm
  module Dig
    DIGGABLE_CLASSES = [Hash, Array].freeze

    def self.dig(what, *keys)
      return what.dig(*keys) if what.respond_to?(:dig)

      if diggable?(what)
        value = what[keys.shift]
        return value if value.nil? || keys.empty?
        return dig(value, *keys)
      end

      fail TypeError, "#{value.class} is not diggable"
    end

    def self.diggable?(what)
      DIGGABLE_CLASSES.include?(what.class)
    end
  end
end
