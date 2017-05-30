require_relative 'tcpws'

module TcpWs
  class Handler < EM::Connection
    include Base

    class << self
      attr_accessor :digest, :ws
    end

    def receive_data(data)
      ws.send("#{digest}:#{data.bytes.join(".")}")
    end

    private

    def digest
      self.class.digest
    end

    def ws
      self.class.ws
    end
  end
end