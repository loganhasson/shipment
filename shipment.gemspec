# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shipment/version'

Gem::Specification.new do |spec|
  spec.name          = "shipment"
  spec.version       = Shipment::VERSION
  spec.authors       = ["Logan Hasson"]
  spec.email         = ["logan.hasson@gmail.com"]
  spec.summary       = "Easy deployment using Docker"
  spec.description   = "Automatically deploy Rails apps to DigitalOcean in a \
                        Docker container."
  spec.homepage      = "http://github.com/loganhasson/shipment"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib", "bin", "config"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "spec"

  spec.add_runtime_dependency "net-ssh"
  spec.add_runtime_dependency "digitalocean"
  spec.add_runtime_dependency "octokit"
end

