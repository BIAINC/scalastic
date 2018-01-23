module Scalastic
  class Scroller

    def initialize(es_client, args)
      @es_client = es_client
      @args = args
      @scroll = '1m'
    end

    def scroll=(value)
      raise(ArgumentError, "scroll cannot be empty!") if value.nil? || value.empty?
      @scroll = value
    end

    attr_reader(:scroll)

    def hits
      Enumerator.new do |enum|
        args = {scroll: scroll}.merge(@args)
        res = @es_client.search(args)
        scroll_id = nil
        loop do
          hits = HashHelper.safe_get(res, 'hits', 'hits')
          break if hits.empty?
          hits.each{|h| enum << h}
          scroll_id = HashHelper.safe_get(res, '_scroll_id')
          res = @es_client.scroll(scroll_id: scroll_id, scroll: scroll)
        end
        @es_client.clear_scroll(scroll_id: scroll_id) if scroll_id
      end
    end
  end
end
