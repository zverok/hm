module RubyDig
  def dig(key, *rest)
    value = self[key]
    if value.nil? || rest.empty?
      value
    elsif value.respond_to?(:dig)
      value.dig(*rest)
    else
      fail TypeError, "#{value.class} is not diggable"
    end
  end
end

INCLUDE_CLASSES = [Array, Hash].freeze

INCLUDE_CLASSES.each { |klass| klass.send(:include, RubyDig) unless klass.method_defined?(:dig) }
