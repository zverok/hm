require 'json'
$:.unshift 'lib'
require 'hm'
require 'pp'

data = JSON.parse(File.read('examples/weather.json'))

pp Hm.new(data)
  .except(['sys', 'id'], ['weather', :*, 'id'])
  .transform(
    ['main', :*] => :*,
    ['sys', :*] => :*,
    ['coord', :*] => 'coord',
    ['weather', 0] => 'weather',
    'dt' => 'timestamp'
  )
  .transform_values('timestamp', 'sunrise', 'sunset', &Time.method(:at))
  .cleanup
  .to_h
