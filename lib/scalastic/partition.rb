require 'scalastic/es_actions_generator'
require 'scalastic/partition_selector'
require 'scalastic/scroller'
require 'scalastic/hash_helper'

module Scalastic
  class Partition

    Endpoint = Struct.new(:index, :routing)
    Endpoints = Struct.new(:index, :search)

    attr_reader(:es_client)
    attr_reader(:config)
    attr_reader(:id)

    def initialize(es_client, config, id)
      raise(ArgumentError, 'ES client is nil!') if es_client.nil?
      raise(ArgumentError, 'config is nil!') if config.nil?
      raise(ArgumentError, 'id is empty!') if id.nil? || id.to_s.empty?

      @es_client = es_client
      @config = config
      @id = id
    end

    def extend_to(args)
      index = args[:index]
      raise(ArgumentError, 'Missing required argument :index') if index.nil? || index.to_s.empty?

      index_alias = config.index_endpoint(id)
      indices = HashHelper.deep_stringify_keys(get_aliases(index_alias)).select{|i, d| d['aliases'].any?}.keys
      actions = indices.map{|i| {remove: {index: i, alias: index_alias}}}
      actions << {add: EsActionsGenerator.new_index_alias(config, args.merge(id: id))}
      actions << {add: EsActionsGenerator.new_search_alias(config, args.merge(id: id))}
      es_client.indices.update_aliases(body: {actions: actions})
    end

    def search(args = {})
      args = args.merge(index: config.search_endpoint(id))
      es_client.search(args)
    end

    def msearch(args)
      endpoint = config.search_endpoint(id)

      es_client.msearch(args.merge(index: endpoint))
    end

    def get(args)
      args = args.merge(index: config.search_endpoint(id))
      es_client.get(args)
    end

    def mget(args)
      args = args.merge(index: config.search_endpoint(id))
      es_client.mget(args)
    end

    def index(args)
      args[:body] ||= {}
      selector.apply_to(args[:body])
      args = args.merge(index: config.index_endpoint(id))
      es_client.index(args)
    end

    def create(args)
      args[:body] ||= {}
      selector.apply_to(args[:body])
      args = args.merge(index: config.index_endpoint(id))
      es_client.create(args)
    end

    def delete(args = {})
      args = args.merge(index: config.search_endpoint(id))
      es_client.delete(args)
    end

    def exists?
      names = [config.search_endpoint(id), config.index_endpoint(id)]
      alias_response = get_aliases(*names)
      all_aliases = HashHelper.deep_stringify_keys(alias_response)
      all_aliases.any?{|_index, data| data['aliases'].any?}
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      false
    end

    def bulk(args)
      body = args.clone[:body] || raise(ArgumentError, 'Missing required argument :body')

      new_ops = body.map{|entry| [operation_name(entry), entry]}.reduce([]){|acc, op| acc << [op.first, update_entry(acc, *op)]; acc}
      args[:body] = new_ops.map{|_op, entry| entry}

      es_client.bulk(args)
    end

    def delete_by_query(args)
      # We're not using ES's delete_by_query endpoint because it doesn't have stable
      # semantics across v2.4-6.1. We can go to using it once we're not straddling versions
      args = args.merge(index: config.search_endpoint(id), scroll: '1m', size: 500, stored_fields: [])
      results = es_client.search(args)
      loop do
        ops = results['hits']['hits'].map{|h| delete_op(h)}
        break if ops.empty?
        es_client.bulk(body: ops)
        scroll_id = results['_scroll_id']
        results = es_client.scroll(scroll_id: scroll_id, scroll: '1m')
      end
    end

    def inspect
      "ES partition #{id}"
    end

    def get_endpoints
      sa = config.search_endpoint(id)
      ia = config.index_endpoint(id)
      aliases = HashHelper.deep_stringify_keys(get_aliases(sa, ia))
      sas = aliases.map{|i, d| [i, d['aliases'][sa]]}.reject{|_i, sa| sa.nil?}
      ias = aliases.map{|i, d| [i, d['aliases'][ia]]}.reject{|_i, ia| ia.nil?}
      Endpoints.new(
        ias.map{|i, ia| Endpoint.new(i, ia['index_routing']).freeze}.first,
        sas.map{|i, sa| Endpoint.new(i, sa['search_routing']).freeze}.freeze
      ).freeze
    end

    # odd rigamarole because Elastic removed the GET verb from /indices/_aliases.
    # Gotta fall back to /indices/_alias, but handle 404 errors cleanly
    def get_aliases(*names)
      raise(ArgumentError,"Invalid names type") unless names.all?{|n| n.is_a?(String)}
      return {} if names.empty?
      # The usual case is that the names are all there, so we can just call get_alias
      raw = es_client.indices.get_alias(name: names.join(","))
      HashHelper.deep_stringify_keys(raw)
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      # one or more of the aliases isn't there. Get all aliases and filter down to what was requested.
      raw = es_client.indices.get_aliases
      HashHelper.transform_values(raw) do |k, v|
        selected = HashHelper.slice(v["aliases"] || v[:aliases], *names)
        selected.empty? ? nil : {'aliases' => selected}
      end
    end

    def index_to(args)
      ie = config.index_endpoint(id)
      eps = get_endpoints
      actions = []
      actions << {remove: {index: eps.index.index, alias: ie}} if eps.index
      actions << {add: EsActionsGenerator.new_index_alias(config, args.merge(id: id))} unless args.nil?
      #TODO: log a warning if there're no updates
      es_client.indices.update_aliases(body: {actions: actions}) if actions.any?
    end

    def readonly?
      get_endpoints.index.nil?
    end

    def scroll(args)
      args = args.merge(index: config.search_endpoint(id))
      Scroller.new(es_client, args).hits
    end

    private

    def operation_name(entry)
      [:create, :index, :update, :delete].find{|name| entry.has_key?(name)}
    end

    def update_entry(acc, operation, entry)
      if (operation)
        op_data = entry[operation]
        op_data[:_index] = config.index_endpoint(id)
        selector.apply_to(op_data[:data]) if op_data.has_key?(:data) && [:index, :create].include?(operation)
      else
        parent = acc.last
        # A previous record must be create/index/update/delete
        raise(ArgumentError, "Unexpected entry: #{entry}") unless parent && parent.first
        selector.apply_to(entry) if [:index, :create].include?(parent.first)
      end
      entry
    end

    def delete_op(hit)
      ret = {delete: {_index: hit['_index'], _id: hit['_id']}}
      ret[:delete][:_type] = hit['_type'] if hit['_type']
      ret
    end

    def selector
      @selector ||= PartitionSelector.new(config.partition_selector, id)
    end
  end
end
