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
end
