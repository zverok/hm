RSpec.describe Hm do
  subject(:hm) { described_class.new(data) }

  def result_of(method)
    ->(*args) {
      if args.last.is_a?(Proc)
        hm.public_send(method, *args[0..-2], &args.last).to_h
      else
        hm.public_send(method, *args).to_h
      end
    }
  end

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
    subject { result_of(:bury) }

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
    subject { result_of(:transform) }

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

    it 'supports value processing' do
      expect(hm.transform(%i[a is * y] => :ys, &:to_s).to_h)
        .to eq(a: {b: 1, is: [{x: 1}, {x: 4}]}, ys: %w[2 5])
    end
  end

  describe '#update' do
    subject { result_of(:update) }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}}
    }

    its_call(%i[a b] => %i[a bb]) { is_expected.to ret(a: {b: 1, bb: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}) }
  end

  describe '#transform_values' do
    subject { result_of(:transform_values) }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}}
    }

    its_call(%i[a is * y], :to_s.to_proc) {
      is_expected.to ret(a: {b: 1, is: [{x: 1, y: '2'}, {x: 4, y: '5'}]})
    }

    its_call(%i[a is * *], :to_s.to_proc) {
      is_expected.to ret(a: {b: 1, is: [{x: '1', y: '2'}, {x: '4', y: '5'}]})
    }

    its_call(%i[a is *], :to_s.to_proc) {
      is_expected.to ret(a: {b: 1, is: ['{:x=>1, :y=>2}', '{:x=>4, :y=>5}']})
    }
    its_call(:a, ->(*) { 1 }) {
      is_expected.to ret(a: 1)
    }
  end

  describe '#except' do
    subject { result_of(:except) }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}}
    }

    its_call(%i[a is * y]) {
      is_expected.to ret(a: {b: 1, is: [{x: 1}, {x: 4}]})
    }
    its_call([:a, :is, 1]) {
      is_expected.to ret(a: {b: 1, is: [{x: 1, y: 2}]})
    }
  end

  describe '#slice' do
    subject { result_of(:slice) }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}}
    }

    its_call(%i[a is * y]) {
      is_expected.to ret(a: {is: [{y: 2}, {y: 5}]})
    }
    its_call([:a, :is, 1, :y]) {
      is_expected.to ret(a: {is: [nil, {y: 5}]})
    }
  end

  describe '#transform_keys' do
    subject { result_of(:transform_keys) }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}}
    }

    its_call(:to_s.to_proc) {
      is_expected.to ret('a' => {'b' => 1, 'is' => [{'x' => 1, 'y' => 2}, {'x' => 4, 'y' => 5}]})
    }
    its_call(%i[a is * *], :to_s.to_proc) {
      is_expected.to ret(a: {b: 1, is: [{'x' => 1, 'y' => 2}, {'x' => 4, 'y' => 5}]})
    }
    # TODO: Not sure what will be right thing to do here. Does not work, anyways
    # its_call(%i[a is *], :succ.to_proc) {
    #   is_expected.to ret(a: {b: 1, is: [nil, {x: 1, y: 2}, {x: 4, y: 5}]})
    # }
  end

  describe '#compact' do
    subject { result_of(:compact) }

    let(:data) {
      {a: {b: nil, is: [{x: nil, y: 2}, {x: 4, y: 5}, nil]}}
    }

    it { is_expected.to ret(a: {is: [{y: 2}, {x: 4, y: 5}]}) }
  end

  describe '#cleanup' do
    subject { result_of(:cleanup) }

    let(:data) {
      {a: {b: nil, c: {}, is: [{x: nil, y: 2}, {x: 4, y: ''}, [nil]]}}
    }

    it { is_expected.to ret(a: {is: [{y: 2}, {x: 4}]}) }
  end

  describe '#select' do
    subject { result_of(:select) }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}}
    }

    its_call(->(path, val) { path.last == :y && val > 3 }) {
      is_expected.to ret(a: {is: [nil, {y: 5}]})
    }
    its_call(%i[a is * y], ->(_, val) { val > 3 }) {
      is_expected.to ret(a: {is: [nil, {y: 5}]})
    }
  end

  describe '#reject' do
    subject { result_of(:reject) }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}}
    }

    its_call(->(path, val) { path.last == :y && val < 3 }) {
      is_expected.to ret(a: {b: 1, is: [{x: 1}, {x: 4, y: 5}]})
    }
    its_call(%i[a is * y], ->(_, val) { val < 3 }) {
      is_expected.to ret(a: {b: 1, is: [{x: 1}, {x: 4, y: 5}]})
    }
  end

  describe '#reduce' do
    subject { result_of(:reduce) }

    let(:data) {
      {a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}]}}
    }

    its_call({%i[a is * y] => %i[a ys]}, :+.to_proc) {
      is_expected.to ret(a: {b: 1, is: [{x: 1, y: 2}, {x: 4, y: 5}], ys: 7})
    }
  end

  describe 'immutability of source' do
    subject(:data) {
      {a: {b: nil, is: [{x: 1, y: 2}, {}]}}
    }

    before { hm.cleanup }

    it { is_expected.to eq(a: {b: nil, is: [{x: 1, y: 2}, {}]}) }
  end
end
