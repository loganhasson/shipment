require 'netrc'
require 'sshkey'
require 'octokit'
require 'digitalocean'
require 'highline/import'

module Shipment

  class Mooring
    attr_accessor :gh_username, :gh_password, :gh_token,
                  :do_client_id, :do_api_key,
                  :ssh_key, :private_key, :public_key
    def self.lash
      new.lash
    end

    def lash
      write_gh_creds
      write_do_creds
      do_ssh_success = setup_do_ssh_key
      while !do_ssh_success
        puts "Your DigitalOcean credentials are invalid. Please try again."
        write_do_creds
        do_ssh_success = setup_do_ssh_key
      end
    end

    def write_gh_creds
      collect_gh_creds
      write_creds(:gh)
    end

    def collect_gh_creds
      self.gh_username = ask('GitHub Username: ')
      self.gh_password = ask('GitHub Password (Never Stored): ') do |q|
        q.echo = false
      end
      self.gh_token = get_gh_token
    end

    def get_gh_token
      success = true
      token_exists = false

      client = Octokit::Client.new(login: gh_username, password: gh_password)

      begin
        authorization = client.create_authorization(
          scopes: [
            "user",
            "repo",
            "public_repo",
            "write:public_key",
            "read:public_key",
            "read:org",
            "read:repo_hook",
            "write:repo_hook",
            "repo_deployment",
            "admin:public_key",
            "admin:repo_hook"
          ],
          note: "Shipment Token"
        )
      rescue Octokit::UnprocessableEntity => e
        success = false
        if !!e.message.match(/already_exists/)
          token_exists = true

          puts <<-MSG.gsub(/^ {12}/,'')
            A token for Shipment already exists for your GitHub account. This 
            may or may not cause issues. Please visit your GitHub account, 
            delete the existing token, and try this setup again.
          MSG
        end
      rescue Octokit::Unauthorized
        success = false
        puts "Your GitHub username and password are invalid. Please try again."
      end

      if success
        return authorization[:token]
      elsif token_exists
        exit
      else
        collect_gh_creds
      end
    end

    def write_do_creds
      collect_do_creds
      write_creds(:do)
    end

    def collect_do_creds
      self.do_client_id = ask("DigitalOcean Client ID: ")
      self.do_api_key = ask("DigitalOcean API Key: ")
    end

    def write_creds(provider)
      netrc = Netrc.read

      if provider == :do
        netrc["shipment.do"] = do_client_id, do_api_key
      elsif provider == :gh
        netrc["shipment.gh"] = gh_username, gh_token
      end

      netrc.save
    end

    def setup_do_ssh_key
      create_key
      transmit_do_key
    end

    def create_key
      self.ssh_key = SSHKey.generate
      self.private_key = write_private_key
      self.public_key = write_public_key
    end

    def write_private_key
      File.open("#{ENV['HOME']}/.ssh/shipment_rsa", "w+") do |f|
        f.write ssh_key.private_key
      end

      return ssh_key.private_key
    end

    def write_public_key
      File.open("#{ENV['HOME']}/.ssh/shipment_rsa.pub", "w+") do |f|
        f.write ssh_key.ssh_public_key
      end

      return ssh_key.ssh_public_key
    end

    def transmit_do_key
      Digitalocean.client_id = do_client_id
      Digitalocean.api_key = do_api_key

      response = Digitalocean::SshKey.create({
        name: 'shipment',
        ssh_pub_key: CGI::escape(public_key)
      })

      if response.status == "ERROR"
        return false
      else
        return true
      end
    end
  end

end
