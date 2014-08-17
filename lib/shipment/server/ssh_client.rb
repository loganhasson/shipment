require 'net/ssh'
require 'netrc'
require 'highline/import'
require 'colorize'

module Shipment
  module Server

    class SSHClient
      attr_reader :ip_address, :repo, :repo_url, :repo_name, :repo_user,
                  :gh_username, :gh_token

      def self.setup(repo:, ip_address:)
        new(repo, ip_address).setup
      end

      def initialize(repo, ip_address)
        @gh_username, @gh_token = Netrc.read["shipment.gh"]
        @ip_address = ip_address
        @repo_url, @repo_name, @repo_user = repo.url, repo.name, repo.user
      end

      def setup
        add_to_known_hosts
        setup_application_container
      end

      def add_to_known_hosts
        puts "-----> ".green + "Adding droplet to known hosts..."
        `/usr/bin/expect <<EOD
        spawn ssh root@#{ip_address}
        expect -re "(continue)"
        send "yes\n"
        send "exit\n"
        expect eof
        EOD`
      end


      def setup_application_container
        puts "-----> ".green + "Preparing server..."
        pull_ruby_image
        puts "-----> ".green + "Setting up application container..."
        generate_ssh_key
        add_deploy_key
        clone_and_bundle
        save_docker_image
      end

      def pull_ruby_image
        puts "-----> ".green + "Pulling base Ruby Image..."
        run_remote_command("docker pull loganhasson/ruby_image")
      end

      def generate_ssh_key
        puts "-----> ".green + "Generating deploy key..."
        run_remote_command("docker run --name setup loganhasson/ruby_image /bin/bash -c 'ssh-keygen -t rsa -N \"\" -C \"#{repo_name}@shipment\" -f \"/root/.ssh/id_rsa\"' && docker commit setup #{repo_user}/#{repo_name} && docker rm setup && docker rmi loganhasson/ruby_image")
      end

      def add_deploy_key
        puts "-----> ".green + "Adding deploy key to GitHub..."
        run_remote_command("docker run --name deploy -e ACCESS_TOKEN=#{gh_token} -e REPO=#{repo_user}/#{repo_name} #{repo_user}/#{repo_name} /bin/bash -c 'source /etc/profile.d/rvm.sh && wget https://gist.githubusercontent.com/loganhasson/e4791b4abe2dc75bc82f/raw/342cd7c32cec4e58947c0eb1785f45abecf714c4/add_deploy_key_shipment.rb && ruby add_deploy_key_shipment.rb && rm add_deploy_key_shipment.rb' && docker commit deploy #{repo_user}/#{repo_name} && docker rm deploy")
      end

      def clone_and_bundle
        puts "-----> ".green + "Installing gems in application container..."
        run_remote_command("docker run --name bundle -e REPO_URL=#{repo_url} -e REPO_NAME=#{repo_name} #{repo_user}/#{repo_name} /bin/bash -c 'source /etc/profile.d/rvm.sh && wget https://gist.githubusercontent.com/loganhasson/5db07d7b5671a9bc5fef/raw/4a28de693b2631c69a888fada82d6b462e2fe09e/clone_with_expect_shipment.sh && chmod +x clone_with_expect_shipment.sh && ./clone_with_expect_shipment.sh && rm clone_with_expect_shipment.sh && cd #{repo_name} && bundle install && cd ..' && docker commit bundle #{repo_user}/#{repo_name} && docker rm bundle")
      end

      def save_docker_image
        puts "-----> ".green + "Saving docker image and pushing to Docker hub..."
        docker_username = ask("Docker username: ")
        docker_password = ask("Docker password: ") { |q| q.echo = false }
        docker_email = ask("Docker email address: ")

        run_remote_command("apt-get -y update && apt-get -y upgrade && apt-get -y udpate && apt-get -y install expect")
        run_remote_command(<<-SETUP
        /usr/bin/expect <<EOD
        spawn docker login
        expect "Username:"
        send "#{docker_username}\n"
        expect "Password:"
        send "#{docker_password}\n"
        expect "Email:"
        send "#{docker_email}\n"
        expect eof
        EOD
        SETUP
        )
        run_remote_command("docker push #{repo_user}/#{repo_name}")
      end

      def run_remote_command(command)
        puts "-----> ".green + "#{command}"
        Net::SSH.start(ip_address, 'root') do |ssh|
          ssh.open_channel do |channel|
            channel.exec "#{command}" do |ch, success|
              raise "problem executing command: #{command}".red unless success

              ch.on_data do |c, data|
                if !data.empty? && !(data == " ") && !(data == "\n") && !data.match(/ojbects|deltas/) && !(data == ".")
                  $stdout.puts "       #{data.strip.chomp}"
                end
              end

              ch.on_extended_data do |c, type, data|
                if !data.empty? && !(data == " ") && !(data == "\n") && !(data == ".")
                  $stderr.puts "       #{data.strip.chomp}".red
                end
              end

              ch.on_close { puts "-----> ".green + "Done." }
            end
          end
        end
      end
    end

  end
end

