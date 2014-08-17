module Shipment
  module Server
    class Expect
      def self.execute(command)
        `/usr/bin/expect #{command}`
      end
    end
  end
end
