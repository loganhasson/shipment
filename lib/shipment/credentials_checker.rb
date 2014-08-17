require 'netrc'

module Shipment

  class CredentialsChecker
    attr_reader :netrc

    def self.verify
      new.verify
    end

    def initialize
      @netrc = Netrc.read
    end

    def verify
      ![netrc["shipment.gh"], netrc["shipment.do"]].flatten.any? do |cred|
        cred.nil? || cred.empty? || cred == " "
      end
    end
  end

end
