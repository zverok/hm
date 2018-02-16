require 'json'
require 'pp'

$LOAD_PATH.unshift 'lib'
require 'hm'

data = JSON.parse(File.read('examples/weather.json'))
pp data

pp Hm.new(data)
  .transform_keys(&:to_sym)                         # symbolize all keys
  .except(:id, :cod, %i[sys id], %i[weather * id])  # remove some system values
  .transform(
    %i[main *] => :*,                               # move all {main: {temp: 1}} to just {temp: 1}
    %i[sys *] => :*,                                # same for :sys
    %i[coord *] => :coord,                          # gather values for coord.lat, coord.lng into Array in coord:
    [:weather, 0] => :weather,                      # move first of :weather Array to just weather: key
    dt: :timestamp                                  # rename :dt to :timestamp
  )
  .cleanup                                          # remove now empty main: {} and sys: {} hashes
  .transform_values(
    :timestamp, :sunrise, :sunset,
    &Time.method(:at))                              # parse timestamps
  .bury(:weather, :comment, 'BAD')                  # insert some random new key
  .to_h
