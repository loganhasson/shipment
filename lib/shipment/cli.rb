require 'shipment/mooring'

module Shipment

  class CLI < Thor
    desc "lash", "setup Shipment with your GitHub and DigitalOcean credentials"
    long_desc <<-LONGDESC
      `ship lash` will collect your GitHub and DigitalOcean credentials.
    LONGDESC
    def lash
      Shipment::Mooring.lash
    end

    def this

    end

    def out

    end
  end

end

