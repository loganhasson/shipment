require 'net/ssh'
require 'shipment/server/expect'

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

      def setup
        add_to_known_hosts
      end

      def add_to_known_hosts
       `/usr/bin/expect <<EOD
        spawn ssh root@#{ip_address}
        expect -re "(continue)"
        send "yes\n"
        send "exit\n"
        expect eof
        EOD`
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
