require 'json'
require 'ruby-prof'

$LOAD_PATH.unshift 'lib'
require 'hm'

DATA = JSON.parse(File.read('examples/weather.json'))

def hm
  Hm.new(DATA)
    .transform_keys(&:to_sym)
    .except(:id, :cod, %i[sys id], %i[sys message], %i[weather * id])
    .transform(
      %i[main *] => :*,
      %i[sys *] => :*,
      %i[coord *] => :coord,
      [:weather, 0] => :weather,
      dt: :timestamp
    )
    .cleanup
    .transform_values(
      :timestamp, :sunrise, :sunset,
      &Time.method(:at))
    .bury(:weather, :comment, 'BAD')
    .to_h
end

result = RubyProf.profile do
  10_000.times { hm }
end

RubyProf::GraphHtmlPrinter.new(result).print(File.open('tmp/prof.html', 'w'))
