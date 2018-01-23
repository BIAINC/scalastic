module Scalastic
  module HashHelper
    extend self

    def deep_stringify_keys(hash)
      return hash if hash.keys.first.is_a?(String)
      deep_stringify_keys_internal(hash)
    end

    def safe_get(hash, *keys)
      keys.reduce(hash) do |h, k|
        h && (h[k.to_s] || h[k.to_sym])
      end
    end

    def slice(hash, *keys)
      keys.each_with_object({}) do |k, acc|
        acc[k] = hash[k] if hash.has_key?(k)
      end
    end

    def transform_values(hash, &block)
      hash.each_with_object({}) do |(k,v), acc|
        modified = block.call(k, v)
        acc[k] = modified if modified
      end
    end

    private

    def deep_stringify_keys_internal(object)
      if (object.is_a?(Hash))
        Hash[object.map{|k, v| [k.to_s, deep_stringify_keys_internal(v)]}]
      elsif object.respond_to?(:map)
        object.map{|i| deep_stringify_keys_internal(i)}
      else
        object
      end
    end
  end
end
