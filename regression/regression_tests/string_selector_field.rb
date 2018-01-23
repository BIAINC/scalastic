module RegressionTests
  module StringSelectorField
    extend self

    def cleanup
      client = RegressionTests.es_client
      client.indices.delete index: 'string_selector_field' if client.indices.exists? index: 'string_selector_field'
    end

    def run
      client = RegressionTests.es_client
      partitions = client.partitions

      client.indices.create index: 'string_selector_field'

      selector_type = RegressionTests.es_major_version==2 ? "string": "keyword"
      RegressionTests.prepare_index selector_type, 'string_selector_field'

      partition = partitions.create index: 'string_selector_field', id: 'favorites'
      partition.index type: 'test', body: {title: 'This is a test'}

      sleep 1.5

      hits = partition.search(type: 'test')['hits']['hits']
      raise "Expected 1 result, got #{hits.size}" unless hits.size == 1

      expected = {'title'=>'This is a test', 'scalastic_partition_id'=>'favorites'}
      actual = hits.first['_source']
      raise "Expected: #{expected}, got: #{actual}" unless expected == actual
    end
  end
end
