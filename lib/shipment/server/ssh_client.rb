require 'net/ssh'
require 'netrc'
require 'highline/import'
require 'colorize'

module Shipment
  module Server

    class SSHClient
      attr_reader :ip_address, :repo, :repo_url, :repo_name, :repo_user,
                  :repo_original_name, :gh_username, :gh_token, :db_user,
                  :db_password, :db_name

      def self.setup(repo:, ip_address:)
        new(repo, ip_address).setup
      end

      def initialize(repo, ip_address)
        @gh_username, @gh_token = Netrc.read["shipment.gh"]
        @ip_address = ip_address
        @repo_url, @repo_name, @repo_user, @repo_original_name = repo.url, repo.name, repo.user, repo.original_name
        db_info = YAML.load(File.read('.shipment'))[:database]
        @db_user, @db_password, @db_name = db_info[:username], db_info[:password], db_info[:name]
      end

      def setup
        add_to_known_hosts
        puts "-----> ".green + "Preparing server..."
        setup_database_container
        setup_application_container
      end

      def add_to_known_hosts
        puts "-----> ".green + "Giving server time to prepare for SSH connections (this will take about 1 minute)..."
        sleep 60
        puts "-----> ".green + "Adding droplet to known hosts..."
        FileUtils.touch('known_host.sh')
        FileUtils.chmod('+x', 'known_host.sh')
        File.open('known_host.sh', 'w+') do |f|
          f.write <<-SCRIPT.gsub(/^ {10}/, '')
          #!/bin/bash

          /usr/bin/expect <<EOD
          spawn ssh root@#{ip_address}
          expect -re "(continue)"
          send "yes\\n"
          send "exit\\n"
          expect eof
          EOD
          SCRIPT
        end
        `./known_host.sh && rm known_host.sh`
      end

      def setup_database_container
        puts "-----> ".green + "Setting up database container..."
        pull_postgres_image
        setup_database_user
        start_database_container
      end

      def pull_postgres_image
        puts "-----> ".green + "Pulling Postgres image (this may take a few minutes)..."
        run_remote_command("docker pull loganhasson/postgres_image")
      end

      def setup_database_user
        puts "-----> ".green + "Setting up database user..."
        run_remote_command("docker run --name database -e USER=#{db_user} -e PASSWORD=#{db_password} -e NAME=#{db_name} loganhasson/postgres_image /bin/bash -c 'wget https://gist.githubusercontent.com/loganhasson/d8f8a91875087407ea6a/raw/3e0caf25154dc91e8679edc4ac11a3c45bad27ea/database_setup_shipment.sql && service postgresql start && psql --set \"user=$USER\" --set \"password=$PASSWORD\" --file=database_setup_shipment.sql && createdb -O $USER $NAME && service postgresql stop && rm database_setup_shipment.sql' && docker commit database #{repo_user}/#{repo_name}_db && docker rm database && docker rmi loganhasson/postgres_image")
      end

      def start_database_container
        puts "-----> ".green + "Starting postgres server..."
        run_remote_command("docker run --name database -d -p 5432:5432 #{repo_user}/#{repo_name}_db su postgres -c '/usr/lib/postgresql/9.3/bin/postgres -D /var/lib/postgresql/9.3/main -c config_file=/etc/postgresql/9.3/main/postgresql.conf'")
      end

      def setup_application_container
        puts "-----> ".green + "Setting up application container..."
        pull_ruby_image
        generate_ssh_key
        add_deploy_key
        clone_and_bundle
        migrate
        #save_docker_image

        puts "-----> ".green + "Done.\nReady to deploy."
        puts "Your server's IP Address is: #{ip_address}"
      end

      def pull_ruby_image
        puts "-----> ".green + "Pulling Ruby image (this may take a few minutes)..."
        run_remote_command("docker pull loganhasson/ruby_image")
      end

      def generate_ssh_key
        puts "-----> ".green + "Generating deploy key..."
        run_remote_command("docker run --name setup loganhasson/ruby_image /bin/bash -c 'ssh-keygen -t rsa -N \"\" -C \"#{repo_name}@shipment\" -f \"/root/.ssh/id_rsa\"' && docker commit setup #{repo_user}/#{repo_name} && docker rm setup && docker rmi loganhasson/ruby_image")
      end

      def add_deploy_key
        puts "-----> ".green + "Adding deploy key to GitHub..."
        run_remote_command("docker run --name deploy -e ACCESS_TOKEN=#{gh_token} -e REPO=#{repo_user}/#{repo_original_name} #{repo_user}/#{repo_name} /bin/bash -c 'source /etc/profile.d/rvm.sh && wget https://gist.githubusercontent.com/loganhasson/e4791b4abe2dc75bc82f/raw/342cd7c32cec4e58947c0eb1785f45abecf714c4/add_deploy_key_shipment.rb && ruby add_deploy_key_shipment.rb && rm add_deploy_key_shipment.rb' && docker commit deploy #{repo_user}/#{repo_name} && docker rm deploy")
      end

      def clone_and_bundle
        puts "-----> ".green + "Cloning project into application container..."
        run_remote_command("docker run --name bundle -e REPO_URL=#{repo_url} -e REPO_NAME=#{repo_name} #{repo_user}/#{repo_name} /bin/bash -c 'source /etc/profile.d/rvm.sh && wget https://gist.githubusercontent.com/loganhasson/5db07d7b5671a9bc5fef/raw/4a28de693b2631c69a888fada82d6b462e2fe09e/clone_with_expect_shipment.sh && chmod +x clone_with_expect_shipment.sh && ./clone_with_expect_shipment.sh && rm clone_with_expect_shipment.sh && cd #{repo_name} && bundle install && cd ..' && docker commit bundle #{repo_user}/#{repo_name} && docker rm bundle")
      end

      def migrate
        puts "-----> ".green + "Migrating database..."
        run_remote_command("docker run --name migrate #{repo_user}/#{repo_name} /bin/bash -c 'source /etc/profile.d/rvm.sh && cd #{repo_name} && bundle exec rake db:migrate'")
      end

      #def save_docker_image
        #puts "-----> ".green + "Installing required packages (this may take a few minutes)..."
        #run_remote_command("apt-get -y update && apt-get -y upgrade && apt-get -y udpate && apt-get -y install expect", true)

        #puts "-----> ".green + "Saving docker images and pushing to Docker hub..."
        #docker_username = ask("Docker username: ")
        #docker_password = ask("Docker password: ") { |q| q.echo = false }
        #docker_email = ask("Docker email address: ")

        #run_remote_command(<<-SETUP
        #/usr/bin/expect <<EOD
        #spawn docker login
        #expect "Username:"
        #send "#{docker_username}\n"
        #expect "Password:"
        #send "#{docker_password}\n"
        #expect "Email:"
        #send "#{docker_email}\n"
        #expect eof
        #EOD
        #SETUP
        #)
        #run_remote_command("docker push #{repo_user}/#{repo_name} && docker push #{repo_user}/#{repo_name}_db")
      #end

      def run_remote_command(command, silent=false)
        puts "-----> ".blue + "#{command}"

        begin
          Net::SSH.start(ip_address, 'root', timeout: 500) do |ssh|
            ssh.open_channel do |channel|
              channel.exec "#{command}" do |ch, success|
                raise "problem executing command: #{command}".red unless success

                ch.on_data do |c, data|
                  if !silent
                    if !data.empty? && !(data == " ") && !(data == "\n") && !data.match(/ojbects|deltas/) && !(data == ".")
                      $stdout.puts "       #{data.strip.chomp}"
                    end
                  end
                end

                ch.on_extended_data do |c, type, data|
                  if !data.empty? && !(data == " ") && !(data == "\n") && !(data == ".")
                    $stderr.puts "       #{data.strip.chomp}".red

                    if data.strip.chomp.match(/Error pulling image/) || data.strip.chomp.match(/connection timed out/)
                      $stderr.puts "-----> ".red + "CONNECTION TO DOCKER TIMED OUT: ".red + "Trying again..."
                      run_remote_command(command, silent)
                    end
                  end
                end

                #ch.on_close { puts "-----> ".green + "Done." }
              end
            end
          end
        rescue Errno::ETIMEDOUT
          $stderr.puts "-----> ".red + "CONNECTION TO SERVER TIMED OUT: ".red + "Reconnecting..."
          run_remote_command(command, silent)
        end
      end
    end

  end
end

