class Hm
  module Dig
    DIGGABLE_CLASSES = [Hash, Array].freeze

    def self.dig(what, *keys)
      if what.respond_to?(:dig)
        return what.dig(*keys)
      elsif diggable?(what)
        value = what[keys.shift]
        return value if value.nil? || keys.empty?
        return self.dig(value, *keys)
      end

      fail TypeError, "#{value.class} is not diggable"
    end

    def self.diggable?(what)
      DIGGABLE_CLASSES.include?(what.class)
    end
  end
end
