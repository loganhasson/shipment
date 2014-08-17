require 'shipment/server/initializer'
require 'shipment/project/repo'

module Shipment

  class Rigging
    def self.rig
      new.rig
    end

    def rig
      Shipment::Server::Initializer.spin_up(Shipment::Project::Repo.new)
    end
  end

end
