require 'net/ssh'

module Shipment
  module Server

    class SSHClient
      attr_reader :ip_address, :repo_url

      def self.setup(ip_address:, repo_url:)
        new(ip_address, repo_url).setup
      end

      def initialize(ip_address, repo_url)
        @ip_address = ip_address
        @repo_url = repo_url
      end

      # 3. SSH into droplet and:
      #   a. Pull loganhasson/ruby_image
      #   b. Generate SSH key and add to github as deploy key
      #   c. Clone repo into container, bundle, remove dir
      #   d. Commit container changes
      #   e. Remove loganhasson/ruby_image
      #   f. Remove stopped containers and untagged images
    end

  end
end
