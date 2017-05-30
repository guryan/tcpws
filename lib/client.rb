require_relative 'tcpws'

module TcpWs
  module Client
    include Base
    configure :listen

    def self.new
      start {
        Signal.trap("INT")  { get("#{config[:ws]}/closed",quit(true)) }
        listen config[:host], config[:port]
        get "#{config[:ws]}/opened"
      }
    end

    def post_init
      @buffer = []
      @ws = connect config[:ws]
      Events.each {|e| ws.on e, method(e).call }
      # ws.send Connected
    end

    def unbind
      # ws.send Disconnected
    end

    def receive_data(data)
      if @digest
        ws.send("#{@digest}:#{data.bytes.join(".")}")
      else
        @buffer << data.bytes.join(".")
      end
    end

    def message
      ->(e) { process(e.data) }
    end

    private

    def process(data)
      set_digest(data)
      digest, data = data.split(":")
      if data
        data = data.split(".")
        send_data data.map{|c| [c.to_i].pack("C") }.join
      end
    end

    def set_digest(data)
      if @digest.nil?
        digest = data.match(/dig(\d{8})est/)
        if digest
          @digest = digest[1] 
          @buffer.each {|msg| ws.send("#{@digest}:#{msg}") } 
        end
      end      
    end

  end
end