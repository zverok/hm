RSpec.describe Hm do
  subject(:hm) { described_class.new(data) }

  let(:data) {
    {
      order: {
        time: Time.parse('2017-03-01 14:30'),
        items: [
          {title: 'Beer', price: 10.0},
          {title: 'Beef', price: 5.0},
          {title: 'Potato', price: 7.8}
        ]
      }
    }
  }

  describe '#dig' do
    subject { hm.method(:dig) }

    context 'regular' do
      its_call(:order, :time) { is_expected.to ret Time.parse('2017-03-01 14:30') }
      its_call(:order, :items, 0, :price) { is_expected.to ret 10.0 }
      its_call(:order, :total) { is_expected.to ret nil }
      its_call(:order, :items, 4, :price) { is_expected.to ret nil }
      its_call(:order, :items, 2, :price, :count) { is_expected.to raise_error TypeError }
    end

    context 'wildcards' do
      its_call(:order, :*) {
        is_expected.to ret [
          Time.parse('2017-03-01 14:30'),
          [
            {title: 'Beer', price: 10.0},
            {title: 'Beef', price: 5.0},
            {title: 'Potato', price: 7.8}
          ]
        ]
      }
      its_call(:order, :items, :*, :price) { is_expected.to ret [10.0, 5.0, 7.8] }
      its_call(:order, :items, :*, :id) { is_expected.to ret [nil, nil, nil] }
      its_call(:order, :time, :*) { is_expected.to raise_error TypeError }
    end
  end

  describe '#dig!' do
    subject { hm.method(:dig!) }

    context 'regular' do
      its_call(:order, :time) { is_expected.to ret Time.parse('2017-03-01 14:30') }
      its_call(:order, :items, 0, :price) { is_expected.to ret 10.0 }
      its_call(:order, :total) { is_expected.to raise_error KeyError }
      its_call(:order, :items, 4, :price) { is_expected.to raise_error 'Key not found: :order/:items/4' }
      its_call(:order, :items, 2, :price, :count) { is_expected.to raise_error TypeError }
    end

    context 'wildcards' do
      its_call(:order, :*) {
        is_expected.to ret [
          Time.parse('2017-03-01 14:30'),
          [
            {title: 'Beer', price: 10.0},
            {title: 'Beef', price: 5.0},
            {title: 'Potato', price: 7.8}
          ]
        ]
      }
      its_call(:order, :items, :*, :price) { is_expected.to ret [10.0, 5.0, 7.8] }
      its_call(:order, :items, :*, :id) { is_expected.to raise_error KeyError }
      its_call(:order, :time, :*) { is_expected.to raise_error TypeError }
    end
  end

  describe '#bury' do
    subject { ->(*args) { hm.bury(*args).to_h } }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}]}}
    }

    context 'regular' do
      its_call(:a, :n, 3) { is_expected.to ret(a: {b: 1, is: [{x: 1, y: 2}], n: 3}) }
      its_call(:a, :n, :c, 3) { is_expected.to ret(a: {b: 1, is: [{x: 1, y: 2}], n: {c: 3}}) }
      its_call(:a, :is, 0, 'replaced') { is_expected.to ret(a: {b: 1, is: ['replaced']}) }
      its_call(:a, :is, 1, 'inserted') { is_expected.to ret(a: {b: 1, is: [{x: 1, y: 2}, 'inserted']}) }
    end

    context 'wildcards' do
      its_call(:a, :*, 3) { is_expected.to ret(a: {b: 3, is: 3}) }

      its_call(:a, :is, :*, 'x') { is_expected.to ret(a: {b: 1, is: ['x']}) }
      its_call(:a, :is, :*, :t, 'x') { is_expected.to ret(a: {b: 1, is: [{x: 1, y: 2, t: 'x'}]}) }
    end
  end

  describe '#transform' do
    subject { ->(*args) { hm.transform(*args).to_h } }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}}
    }

    context 'regular' do
      its_call(%i[a b] => %i[a bb]) { is_expected.to ret(a: {bb: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}) }
      its_call(%i[a b] => %i[a bb], [:a, :is, 0] => %i[a first]) {
        is_expected.to ret(a: {bb: 1, is: [{x: 4, y: 5}], first: {x: 1, y: 2}})
      }
    end

    context 'wildcards' do
      its_call(%i[a *] => %i[a x]) {
        is_expected.to ret(a: {x: [1, [{x: 1, y: 2}, {x: 4, y: 5}]]})
      }
      its_call(%i[a *] => %i[a x *]) {
        is_expected.to ret(a: {x: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}})
      }
      its_call(%i[a is * y] => %i[a is * yy]) {
        is_expected.to ret(a: {b: 1, is: [{x: 1, yy: 2}, {x: 4, yy: 5}]})
      }
      its_call(%i[a is * y] => %i[a ys *]) {
        is_expected.to ret(a: {b: 1, is: [{x: 1}, {x: 4}], ys: [2, 5]})
      }
      its_call(%i[a is * y] => %i[a ys * m]) {
        is_expected.to ret(a: {b: 1, is: [{x: 1}, {x: 4}], ys: [{m: 2}, {m: 5}]})
      }
    end
  end
end
