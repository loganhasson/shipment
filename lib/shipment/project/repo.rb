require 'git'
require 'netrc'
require 'yaml'

module Shipment
  module Project

    class Repo
      attr_accessor :repo, :url, :user, :name, :original_name

      def initialize
        self.repo = Git.open(FileUtils.pwd)
        parse_details
      end

      def parse_details
        get_url
        get_user
        get_name
      end

      def get_url
        self.url = repo.remotes.detect do |remote|
          remote.name == "origin"
        end.url
      end

      def get_user
        self.user = url.match(/(?:https:\/\/|git@)github\.com(?:\:|\/)(.*)\/.+(?:\.git)?/)[1]
      end

      def get_name
        self.original_name = url.match(/(?:https:\/\/|git@).*\/(.+)(?:\.git)?/)[1].gsub('.git', '')
        self.name = url.match(/(?:https:\/\/|git@).*\/(.+)(?:\.git)?/)[1].gsub('.git', '').gsub('_','-')
      end
    end

  end
end
