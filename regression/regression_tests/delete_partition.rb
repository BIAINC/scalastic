module RegressionTests
  module DeletePartition
    extend self
    
    def cleanup
      client = RegressionTests.es_client
      client.indices.delete index: 'delete_partition' if client.indices.exists? index: 'delete_partition'
    end

    def run
      # Connect to Elasticsearch and create an index
      client = RegressionTests.es_client
      partitions = client.partitions
      client.indices.create index: 'delete_partition'
      RegressionTests.prepare_index "integer", 'delete_partition'

      # Create partitions
      partitions.create index: 'delete_partition', id: 1
      partition = partitions.create index: 'delete_partition', id: 2
      partitions.create index: 'delete_partition', id: 3
      sleep 1.5

      # add a doc. Get it back out w/o index reference
      partition.index id: 1, type: 'test', body: {subject: 'Test 1'}
      results = client.indices.get(index: 'delete_partition', type: 'test', id: 1)
      raise "doc didn't make it into the index" unless results

      # Delete one of the partitions
      partitions.delete id: 2
      sleep 1.5

      # show that removing the partition didn't remove its documents
      results = client.indices.get(index: 'delete_partition', type: 'test', id: 1)
      raise "doc was unexpectedly removed from the index" unless results

      raise 'Partition still exists' if partitions[2].exists?
    rescue
      pp $!.message
      pp $!.backtrace
      raise
    end
  end
end
