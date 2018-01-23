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
      partitions.create index: 'delete_partition', id: 2
      partitions.create index: 'delete_partition', id: 3
      sleep 1.5

      # Delete one of the partitions
      partitions.delete id: 2
      sleep 1.5

      raise 'Partition still exists' if partitions[2].exists?
    rescue
      pp $!.message
      pp $!.backtrace
      raise
    end
  end
end
