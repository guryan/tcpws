require 'rack/proxy'

module TcpWs
  class Proxy < Rack::Proxy

    def perform_request(env)
      # request = Rack::Request.new(env)
      env["rack.ssl_verify_none"] = true
      env["HTTP_HOST"] = "localhost:#{ENV['PROXY_PORT']}"
      super(env)
    end
  end
end