require 'faraday'
require 'json'

module Shipment

  class DNSManager
    attr_accessor :response, :status
    attr_reader :connection, :ip_address, :node, :zone

    def initialize(ip_address:, node:, zone: 'shipmentapp.io')
      @ip_address = ip_address
      @node = node
      @zone = zone
      @connection = Faraday.new(url: '') do |faraday|
        faraday.request  :url_encoded
        faraday.response :logger
        faraday.adapter  Faraday.default_adapter
      end
    end

    def register
      response = connection.post do |request|
        request.url '/nodes'
        request.headers['Content-Type'] = 'application/json'
        request.params[:ip_address] = ip_address
        request.params[:node] = node
        request.params[:zone] = zone
      end

      self.response = JSON.parse(response)
      self.status = reponse["status"]
    end

    def success?
      status == "success"
    end

    def domain
      response["domain"]
    end
  end

end
