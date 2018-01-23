# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "scalastic/version"

Gem::Specification.new do |spec|
  spec.name          = "scalastic"
  spec.version       = Scalastic::VERSION
  spec.authors       = ["TotalDiscovery"]
  spec.email         = ["dev@totaldiscovery.com"]

  spec.summary       = "Elasticsearch document partitions"
  spec.description   = "Elasticsearch alias-based partitions for scalable indexing and searching"
  spec.homepage      = "https://github.com/BIAINC/scalastic"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 1.9"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.4"
  spec.add_development_dependency "simplecov", "~> 0.11"
  spec.add_development_dependency "hashdiff"

  spec.add_dependency "json", "~> 1.8", ">= 1.8.3"
  spec.add_dependency "elasticsearch", "~> 6.0"
end
