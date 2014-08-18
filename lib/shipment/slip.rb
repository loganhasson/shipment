require 'yaml'
require 'shipment/server/ssh_client'
require 'shipment/project/repo'

module Shipment
  class Slip
    def self.cast_off
      new.cast_off
    end

    def cast_off
      Shipment::Server::SSHClient.deploy(
        repo: Shipment::Project::Repo.new,
        ip_address: YAML.load(File.read('.shipment'))[:ip_address]
      )
    end
  end
end
