require_relative 'handler'

module TcpWs
  class Server
    include Base

    configure :proxy

    def initialize
      start {
        Signal.trap("INT") { quit }
        @clients  = {}
        @handlers = {}
        @ws = connect config[:ws]
        Events.each {|event| ws.on event, method(event).call }
      }
    end

    def message
      ->(e) {
        digest, msg = e.data.split(":")
        if msg
          @clients[digest] = connected(digest) if @clients[digest].nil?
          @clients[digest].send_data(msg.split(".").map{|c| [c.to_i].pack("C") }.join)
        end
      }
    end

    def connected(digest)
      connect config[:host], config[:port], handler(digest)
    end

    private

    def handler(digest)
      if @handlers[digest].nil?
        @handlers[digest] = Class.new(TcpWs::Handler)
        @handlers[digest].digest = digest
        @handlers[digest].ws = ws
      end
      @handlers[digest]
    end

  end
end