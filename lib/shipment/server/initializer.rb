require 'digitalocean'
require 'netrc'
require 'shipment/server/ssh_client'

module Shipment
  module Server

    class Initializer
      attr_reader :repo_url, :repo_name, :repo_user
      attr_accessor :droplet

      def self.spin_up(repo)
        new(repo).spin_up
      end

      def initialize(repo)
        @repo_url, @repo_name, @repo_user = repo.url, repo.name, repo.user
        netrc = Netrc.read
        Digitalocean.client_id, Digitalocean.api_key = netrc["shipment.do"]
      end

      def spin_up
        create_droplet
        store_droplet_data
        update_ssh_config
        Shipment::Server::SSHClient.setup(
          ip_address: ip_address,
          repo_url: repo_url
        )
      end

      def create_droplet
        print "Creating Droplet: #{repo_name}"
        self.droplet = Digitalocean::Droplet.create({
          name: repo_name,
          size_id: get_size_id,
          image_id: get_image_id,
          region_id: get_region_id,
          ssh_key_id: get_ssh_key_id
        }).droplet
        print_waiting
      end

      def store_droplet_data
        File.open("#{ENV['HOME']}/.shipment", "a") do |f|
          f.write "#{droplet.id} : #{repo_name} : #{ip_address}\n"
        end
      end

      def update_ssh_config
        File.open("#{ENV['HOME']}/.ssh/config", "a") do |f|
          f.write <<-SSHCONFIG.gsub(/^ {10}/,'')

          Host #{repo_name.gsub(/_|-/,'')} #{ip_address}
          Hostname #{ip_address}
          IdentityFile #{ENV['HOME']}/.ssh/shipment_rsa
          SSHCONFIG
        end
      end

      def get_size_id
        Digitalocean::Size.all.sizes.detect {|size| size.slug == "2gb"}.id
      end

      def get_image_id
        Digitalocean::Image.all.images.detect {|image| image.name.match(/Docker/)}.id
      end

      def get_region_id
        Digitalocean::Region.all.regions.detect {|region| region.slug == "nyc2"}.id
      end

      def get_ssh_key_id
        Digitalocean::SshKey.all.ssh_keys.detect {|key| key.name == "shipment"}.id
      end

      def droplet_created?
        !!(remote_droplet.status == "active")
      end

      def get_ip_address
        remote_droplet.ip_address
      end

      def remote_droplet
        Digitalocean::Droplet.find(droplet.id).droplet
      end

      def print_waiting
        while !droplet_created?
          print "."
          sleep 3
        end

        self.ip_address = get_ip_address
      end
    end
  end
end
