require 'yaml'
require 'shipment/server/ssh_client'
require 'shipment/project/repo'

module Shipment
  class Manifest
    def self.review
      Shipment::Server::SSHClient.tail_logs(
        repo: Shipment::Project::repo.new,
        ip_address: YAML.load(File.read('shipment'))[:ip_address]
      )
    end
  end
end
