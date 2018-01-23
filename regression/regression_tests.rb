require 'pp'
require 'scalastic'
require 'elasticsearch'
require 'hashdiff'

module RegressionTests
  include Enumerable
  extend self

  def es_client
    if ENV["ES_HOST"]
      Elasticsearch::Client.new hosts: ENV["ES_HOST"]
    else
      Elasticsearch::Client.new
    end
  end

  def each(&block)
    Dir.glob('./regression/regression_tests/**.rb').each do |l|
      load l
    end

    RegressionTests.constants.map{|c| RegressionTests.const_get(c)}.select{|c| c.is_a?(Module) && c.respond_to?(:run) && c.respond_to?(:cleanup)}.each(&block)
  end

  def es_major_version
    @es_major_version ||= es_client.perform_request("GET", "").body["version"]["number"].split(".").first.to_i
  end

  def partition_selector_mapping(partition_selector_type)
    type_str = partition_selector_type.to_s
    if es_major_version == 2
      raise(ArgumentError, "Unsupported selector type: #{type_str}. Supported types are: (string, long)") unless %w(string long integer).include?(type_str)
    else
      raise(ArgumentError, "Unsupported selector type: #{type_str}. Supported types are: (keyword, long)") unless %w(keyword long integer).include?(type_str)
    end

    parts = es_client.partitions.config.partition_selector.to_s.split('.').reverse
    field = parts.shift
    parts.reduce(field => {type: partition_selector_type}){|acc, p| {p => {type: 'object', properties: acc}}}
  end

  def prepare_index(partition_selector_type, index)
    mapping = partition_selector_mapping(partition_selector_type)
    Scalastic::PartitionsClient.new(es_client).prepare_index(mapping, index)
  end
end
