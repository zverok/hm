require 'json'
require 'benchmark/ips'

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

def raw
  weather = DATA.dig('weather', 0)
  main = DATA['main']
  sys = DATA['sys']
  {coord: [DATA.dig('coord', 'lat'), DATA.dig('coord', 'lng')],
   weather:
    {main: weather['main'],
     description: weather['description'],
     icon: weather['icon'],
     comment: "BAD"},
   base: DATA['base'],
   visibility: DATA['visibility'],
   wind: {speed: DATA.dig('wind', 'speed'), deg: DATA.dig('wind', 'deg')},
   clouds: {all: DATA.dig('clouds', 'all')},
   name: DATA['name'],
   temp: main['temp'],
   pressure: main['pressure'],
   humidity: main['humidity'],
   temp_min: main['temp_min'],
   temp_max: main['temp_max'],
   type: sys['type'],
   country: sys['country'],
   sunrise: Time.at(sys['sunrise']),
   sunset: Time.at(sys['sunset']),
   timestamp: Time.at(DATA['dt'])}
end

Benchmark.ips do |b|
  b.report('hm') { hm }
  b.report('raw') { raw }

  b.compare!
end
