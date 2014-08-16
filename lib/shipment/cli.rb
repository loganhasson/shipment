require 'thor'
require 'shipment/mooring'

module Shipment

  class CLI < Thor
    desc "lash", "Setup Shipment with your GitHub and DigitalOcean credentials"
    long_desc <<-LONGDESC
      `ship lash` will collect your GitHub and DigitalOcean credentials.
    LONGDESC
    def lash
      Shipment::Mooring.lash
    end

    desc "this", "Prepare your application for deployment"
    long_desc <<-LONGDESC
    `ship this` will setup all necessary files and prepare a remote server for
    deployment.

    This process includes adding the `mina` gem to your Gemfile, creating a new 
    `deploy.rb` file, altering your `database.yml` file for use on the remote 
    server, and ensuring that all necessary SSH keys are in place.

    Alternate usage: `ship .`
    LONGDESC
    def this
      Shipment::Rigging.rig
    end

    desc "out", "Deploy your application"
    long_desc <<-LONGDESC
    `ship out` will deploy your application's master branch to your DigitalOcean 
    server.
    LONGDESC
    def out
      Shipment::Slip.cast_off
    end
  end

end

