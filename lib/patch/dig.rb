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

if RUBY_VERSION < '2.3'
  Array.send(:include, RubyDig)
  Hash.send(:include, RubyDig)
end
