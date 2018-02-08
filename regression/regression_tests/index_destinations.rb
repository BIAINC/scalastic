module RegressionTests
  module IndexDestinations
    extend self

    def cleanup
      client = RegressionTests.es_client
      client.indices.delete index: 'destinations_1' if client.indices.exists? index: 'destinations_1'
      client.indices.delete index: 'destinations_2' if client.indices.exists? index: 'destinations_2'
    end

    def run
      client = RegressionTests.es_client
      partitions = client.partitions

      client.indices.create index: 'destinations_1'
      client.indices.create index: 'destinations_2'

      RegressionTests.prepare_index "integer", 'destinations_1'
      RegressionTests.prepare_index "integer", 'destinations_2'

      p = partitions.create id: 1, index: 'destinations_1'
      p.extend_to(index: 'destinations_2')

      expected = {
        "destinations_1"=> {
          "aliases"=> {
            "scalastic_1_search"=> {
              "filter"=>{"term"=>{"scalastic_partition_id"=>1}}
            }
          }
        },
        "destinations_2"=> {
          "aliases"=> {
            "scalastic_1_index"=>{},
            "scalastic_1_search"=> {
              "filter"=>{"term"=>{"scalastic_partition_id"=>1}}
            }
          }
        }
      }
      actual = client.indices.get_alias name: 'scalastic_1_*'
      diffs = HashDiff.diff(expected, actual)
      pp diffs if diffs.any?
      raise "Expected #{expected}, got: #{actual}" if diffs.any?

      p = partitions[2]
      raise 'Partition should not exist!' if p.exists?
      p = partitions.create id: 2, index: 'destinations_1'
      raise 'Partition should exist!' unless p.exists?

      p.index_to nil

      expected = {
        "destinations_1"=> {
          "aliases"=> {
            "scalastic_2_search"=> {
              "filter"=>{"term"=>{"scalastic_partition_id"=>2}}
            }}
        },
      }

      actual = client.indices.get_alias name: "scalastic_2_*"
      diffs = HashDiff.diff(expected, actual)
      pp diffs if diffs.any?
      raise "Expected: #{expected}, got: #{actual}" if diffs.any?
    rescue
      pp $!.message
      pp $!.backtrace
      raise
    end
  end
end
