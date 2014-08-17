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
        pull_ruby_image
      end

      def add_to_known_hosts
        puts "Adding droplet to known hosts..."
        `/usr/bin/expect <<EOD
        spawn ssh root@#{ip_address}
        expect -re "(continue)"
        send "yes\n"
        send "exit\n"
        expect eof
        EOD`
      end

      def pull_ruby_image
        puts "Adding base ruby_image container to server..."
        run_remote_command("docker pull loganhasson/ruby_image")
      end

      def run_remote_command(command)
        puts "----> #{command}"
        Net::SSH.start(ip_address, 'root') do |ssh|
          ssh.open_channel do |channel|
            channel.exec "#{command}" do |ch, success|
              raise "problem executing command: #{command}" unless success

              ch.on_data do |c, data|
                if !data.empty? && !(data == " ") && !(data == "\n")
                  $stdout.print data
                end
              end

              ch.on_extended_data do |c, type, data|
                if !data.empty? && !(data == " ") && !(data == "\n")
                  $stderr.print data
                end
              end

              ch.on_close { puts "Done." }
            end
          end
        end
      end
      # 3. SSH into droplet and:
      #   b. Generate SSH key and add to github as deploy key
      #     1. Guess this class needs the whole Repo object (username and repo name)
      #     2. Remember to do an expect/clone thing
      #   c. Clone repo into container, bundle, remove dir
      #   d. Commit container changes
      #   e. Remove loganhasson/ruby_image
      #   f. Remove stopped containers and untagged images
    end

  end
end
