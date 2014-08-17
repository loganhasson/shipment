require 'digitalocean'
require 'netrc'

module Shipment
  module Server

    class Initializer
      attr_reader :repo_url

      def self.spin_up(repo_url)
        new(repo_url).spin_up
      end

      def initialize(repo_url)
        @repo_url = repo_url
        netrc = Netrc.read
        Digitalocean.client_id, Digitalocean.api_key = netrc["shipment.do"]
      end

      def spin_up
        # Create a droplet
        # SSH into droplet and:
        #   1. Pull loganhasson/ruby_image
        #   2. Generate SSH key and add to github as deploy key
        #   3. Clone repo into container, bundle, remove dir
        #   4. Commit container changes
        #   5. Remove loganhasson/ruby_image
        #   6. Remove stopped containers and untagged images
      end

    end
  end
end
