module Shipment
  class Slip
    def self.cast_off
      new.cast_off
    end

    def cast_off
      if !File.exist?('.shipment')
        puts "Please run `ship this` to prepare this application for deployment."
      else
        # This is where actual deployment will happen.
      end
    end
  end
end
