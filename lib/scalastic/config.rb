module Scalastic
  class Config
    attr_reader(:partition_prefix)
    attr_reader(:partition_selector)

    def self.default
      @default ||= new
    end

    def initialize
      @partition_prefix = 'scalastic'
      @partition_selector = 'scalastic_partition_id'
    end

    def index_endpoint(partition_id)
      "#{partition_prefix}_#{partition_id}_index"
    end

    def search_endpoint(partition_id)
      "#{partition_prefix}_#{partition_id}_search"
    end

    def get_partition_id(alias_name)
      m = partition_regex.match(alias_name)
      m && m[1]
    end

    def partition_prefix=(value)
      raise(ArgumentError, 'Empty partition prefix') if value.nil? || value.empty?
      @partition_prefix = value
    end

    def partition_selector=(value)
      raise(ArgumentError, 'Empty partition selector') if value.nil? || value.empty?
      @partition_selector = value
    end

    private

    def partition_regex
      @partition_regex ||= begin
        escaped_prefix = Regexp.escape(partition_prefix)
        Regexp.new("^#{escaped_prefix}_(\\w+)_(index|search)$")
      end
    end
  end
end
