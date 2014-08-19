require 'git'
require 'securerandom'
require 'shipment/server/ssh_client'

module Shipment
  module Project

    class Customizer
      attr_accessor :repo_info

      def self.customize
        puts "-----> ".green + "Setting up deployment settings..."
        new.customize
      end

      def initialize
        @repo_info = YAML.load(File.read('.shipment'))
      end

      def customize
        puts "-----> ".green + "Checking for Redis and Sidqkiq..."
        if has_sidekiq?
          add_sidekiq
        elsif has_redis?
          add_redis
        end

        puts "-----> ".green + "Updating database info..."
        update_db_info
        puts "-----> ".green + "Adding .shipment file to .gitignore..."
        add_shipment_to_gitignore
        puts "-----> ".green + "Ensuring correct logging settings..."
        fix_logging_settings
        puts "-----> ".green + "Committing and pushing changes..."
        commit_and_push
      end

      def commit_and_push
        git = Git.open(FileUtils.pwd)
        git.add(all: true)
        git.commit("Setup for deployment with shipment")
        git.push(git.remote("origin"))
      end

      def fix_logging_settings
        remove_12_factor_gem
        update_production_rb
      end

      def remove_12_factor_gem
        if !!File.read('Gemfile').match(/rails_12factor/)
          File.open('Gemfile.tmp', 'w') do |tmp|
            File.readlines('Gemfile').each do |line|
              tmp.write(line) unless line.match(/rails_12factor/)
            end
          end

          FileUtils.mv 'Gemfile.tmp', 'Gemfile'

          system("bundle install > /dev/null")
        end
      end

      def update_production_rb
        File.open('production.rb.tmp', 'w') do |tmp|
          File.readlines('config/environments/production.rb').each do |line|
            if line == 'end' || line == "end\n"
              tmp.write("  config.logger = Logger.new('/var/lib/docker/volumes/log/production.log')\nend")
            else
              tmp.write(line)
            end
          end
        end

        FileUtils.mv 'production.rb.tmp', 'config/environments/production.rb'
      end

      def add_shipment_to_gitignore
        File.open(".gitignore", "a") do |f|
          f.write '.shipment'
        end
      end

      def has_sidekiq?
        !!File.read('Gemfile').match(/sidekiq/)
      end

      def add_sidekiq
        repo_info[:sidekiq] = true
        add_redis
      end

      def has_redis?
        !!File.read('Gemfile').match(/redis/)
      end

      def add_redis
        repo_info[:redis] = true
      end

      def update_shipment_file
        File.open('.shipment', 'w+') do |f|
          f.write repo_info.to_yaml
        end
      end

      def update_db_info
        create_db_creds
        update_shipment_file
        update_db_yaml
      end

      def update_db_yaml
        FileUtils.cp('config/database.yml', 'config/database.yml.bak')
        database_yml = YAML.load(File.read('config/database.yml'))
        database_yml["production"] = {
          "url" => "postgres://#{repo_info[:database][:username]}:#{repo_info[:database][:password]}@#{repo_info[:ip_address]}:5432/#{repo_info[:database][:name]}"
        }
        File.open("config/database.yml", "w+") do |f|
          f.write database_yml.to_yaml
        end
      end

      def create_db_creds
        repo_info[:database] = {
          username: SecureRandom.hex(5).chars.unshift('s').join,
          password: SecureRandom.hex.chars.unshift('s').join,
          name: SecureRandom.hex(10).chars.unshift('s').join
        }
      end
    end

  end
end
