require 'sinatra/base'
require 'digest'
require_relative 'tcpws'
require_relative 'proxy'

module TcpWs
  class App < Sinatra::Base
    Keepalive_Time = 15 # in seconds

    set :root, File.join(File.dirname(__FILE__), "..")

    def initialize
      super
      @clients = {}
      @ws2tcp = spawn("CLIENT_PORT=#{ENV['PROXY_PORT']} bin/client")
      @proxy = Proxy.new
      at_exit  &quit
    end

    def quit
      -> {
        Process.kill(@tcp2ws)
        exit true
      }
    end

    def call(env)
      ws_request?(env) ? ws_request(env) : super
    end


    client_listener_api_handler = -> {
      msg = "client_listener_" + env["REQUEST_PATH"].split("/")[-1]
      send_to_logger("app", msg)
      [200, {}, [msg]]
    }

    get "/client/closed", &client_listener_api_handler

    get "/client/opened", &client_listener_api_handler

    get "/logger", &-> { erb :"logger.html" }

    get "/logger.js", &-> {
      content_type :js
      erb :"logger.js"
    }

    get "/*", &-> { @proxy.call(env) }

    def ws_request?(env)
      Faye::WebSocket.websocket?(env) && (
      env["REQUEST_PATH"] == "/server"  ||
      env["REQUEST_PATH"] == "/client"  ||
      env["REQUEST_PATH"] == "/logger"   )
    end

    def ws_request(env)
      type = env["REQUEST_PATH"].split("/")[-1]
      ws = websocket(env)
      if type == "logger"
        @logger = ws
        send_to_logger("app", "register_logger")
      else
        Events.each{|e| ws.on e, method("#{type}_#{e}").call(ws) }
      end
      ws.rack_response
    end

    def server_open(ws)
      ->(event) {
        @server = ws
        send_to_logger("app", "server_open")
      }
    end

    def server_close(ws)
      ->(event) {
        @server = ws = nil
        send_to_logger("app", "server_close")
      }
    end

    def client_open(ws)
      ->(event) {
        digest = Digest::MD5.digest(Time.now.to_i.to_s).bytes.join[0..7]
        ws.send("dig#{digest}est")
        @clients[digest] = ws
        send_to_logger("app", "client_open")
      }
    end

    def client_close(ws)
      ->(event) {
        @client = ws = nil
        send_to_logger("app", "client_close")
      }
    end

    def server_message(ws)
      ->(event) { send_to_client(event.data) }
    end
    
    def client_message(ws)
      ->(event) { send_to_server(event.data) }
    end
    
    def send_to_server(msg)
      @server.send(msg) if @server
      send_to_logger("client", "send #{msg.bytes.length} bytes")
    end

    def send_to_client(msg)
      digest, data = msg.split(":")
      @clients[digest].send(msg) if @clients[digest]
      send_to_logger("server", "send #{msg.bytes.length} bytes")
    end

    def send_to_logger(sender, msg)
      msg = "#{sender}=#{msg}"
      if @logger
        @logger.send(msg) 
      else
        puts msg
      end
    end

    private

    def websocket(env)
      Faye::WebSocket.new(env, nil, {ping: Keepalive_Time })
    end
  end
end