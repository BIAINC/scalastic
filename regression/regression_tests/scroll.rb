module RegressionTests
  module Scroll
    extend self

    def cleanup
      client = RegressionTests.es_client
      client.indices.delete index: 'scrolling' if client.indices.exists? index: 'scrolling'
    end

    def run
      # Connect to Elasticsearch
      client = RegressionTests.es_client
      client.indices.create index: 'scrolling'
      partitions = client.partitions
      RegressionTests.prepare_index "integer", 'scrolling'

      p = partitions.create id: 1, index: 'scrolling'

      # Create some test data
      (1..10).each do |i|
        p.index(id: i, type: 'test', body: {subject: "Test ##{i}"})
      end

      p.es_client.indices.flush(index: 'scrolling')
      sleep 1.5

      # Get the hits. Size is set to 7 to test multiple calls to scroll
      actual_hits = p.scroll(size: 7).to_a.sort_by{|x| x['_id'].to_i}
      expected_hits = (1..10).map do |i|
        {'_index' => 'scrolling', '_id' => "#{i}", "_type" => "test", '_score' => 1.0, '_source' => {'subject' => "Test ##{i}", 'scalastic_partition_id' => 1} }
      end

      diffs = HashDiff.diff(expected_hits, actual_hits)
      pp diffs if diffs.any?
      raise "Expected: #{expected_hits}, got: #{actual_hits}" if diffs.any?
    rescue
      pp $!.message
      pp $!.backtrace
      raise
    end
  end
end
