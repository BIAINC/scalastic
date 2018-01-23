require 'spec_helper'
require 'scalastic/scroller'

describe Scalastic::Scroller  do
  let(:es_client) {mock_es_client}
  let(:args) {{index: 'whatever'}}

  let(:scroller) {described_class.new(es_client, args)}
  subject {scroller}

  def mock_es_client
    double('es client').tap do |c|
      allow(c).to receive(:search)
      allow(c).to receive(:scroll)
    end
  end

  it {is_expected.to respond_to :scroll}

  describe '#scroll' do
    it 'has a default value' do
      expect(scroller.scroll).to eq '1m'
    end

    it 'rejects nil value' do
      expect{scroller.scroll = nil}.to raise_error(ArgumentError, 'scroll cannot be empty!')
    end

    it 'accepts correct value' do
      scroller.scroll = '2m'
      expect(scroller.scroll).to eq '2m'
    end
  end

  describe '#each' do
    let(:scroll) { "2m" }
    let(:search_results) do
      [
        {'_scroll_id' => 'scroll_2', 'hits' => {'hits' => all_search_hits[0..7]}},
      ]
    end
    let(:all_search_hits) {10.times.map{|i| double("Hit #{i + 1}")}}

    let(:scroll_results) do
      [
        {'_scroll_id' => 'scroll_3', 'hits' => {'hits' => all_search_hits[8..9]}},
        {'hits' => {'hits' => []}}
      ]
    end

    before(:each) do
      scroller.scroll = scroll

      allow(es_client).to receive(:search).and_return(*search_results)
      allow(es_client).to receive(:scroll).and_return(*scroll_results)
      allow(es_client).to receive(:clear_scroll)
    end

    it 'extracts all hits' do
      expect(scroller.hits.to_a).to eq all_search_hits
    end

    it 'passes correct arguments' do
      expect(es_client).to receive(:search).once.ordered.with(args.merge(type: 'test', scroll: scroll)).and_return(*search_results)
      expect(es_client).to receive(:scroll).ordered.with(scroll_id: 'scroll_2', scroll: scroll).and_return(scroll_results[0])
      expect(es_client).to receive(:scroll).ordered.with(scroll_id: 'scroll_3', scroll: scroll).and_return(scroll_results[1])

      scroller.hits.to_a
    end

    it 'clears the scroll' do
      expect(es_client).to receive(:clear_scroll)
      scroller.hits.to_a
    end
  end
end
