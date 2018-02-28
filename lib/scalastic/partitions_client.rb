require 'scalastic/partition'
require 'scalastic/es_actions_generator'
require 'scalastic/hash_helper'

module Scalastic
  class PartitionsClient
    include Enumerable

    attr_reader(:es_client)
    attr_reader(:config)

    def initialize(es_client, config = Config.default.dup)
      raise(ArgumentError, 'ES client is nil') if es_client.nil?
      raise(ArgumentError, 'Config is nil') if config.nil?
      @es_client = es_client
      @config = config
    end

    def create(args = {})
      actions = [
        {add: EsActionsGenerator.new_search_alias(config, args)},
        {add: EsActionsGenerator.new_index_alias(config, args)},
      ]
      es_client.indices.update_aliases(body: {actions: actions})
      self[args[:id]]
    end

    def delete(args = {})
      id = args[:id].to_s
      raise(ArgumentError, 'Missing required argument :id') if id.nil? || id.empty?
      pairs = HashHelper.deep_stringify_keys(es_client.indices.get_aliases).map{|i, d| d['aliases'].keys.select{|a| config.get_partition_id(a) == id}.map{|a| [i, a]}}.flatten(1)
      unless pairs.any?
        #TODO: log a warning
        return
      end
      actions = pairs.map{|i, a| {remove: {index: i, alias: a}}}
      es_client.indices.update_aliases(body: {actions: actions})
    end

    def [](id)
      Partition.new(es_client, config, id)
    end

    def each(&_block)
      partition_ids.each{|pid| yield Partition.new(es_client, config, pid) if block_given?}
    end

    def prepare_index(partition_selector_mapping, index)
      raise(ArgumentError, 'Missing required argument :index') unless index
      mapping = {properties: partition_selector_mapping}
      es_client.indices.put_mapping(index: index, type: 'test', body: {'test' => mapping})
    end

    private

    def partition_ids
      aliases = HashHelper.deep_stringify_keys(es_client.indices.get_aliases)
      partition_ids = aliases.map{|_, data| data['aliases'].keys}.flatten.map{|a| config.get_partition_id(a)}.compact.uniq
    end
  end
end
