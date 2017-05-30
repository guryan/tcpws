require 'faye/websocket'
require 'em-http-request'

module TcpWs
  Connected    = "post_init"
  Disconnected = "unbind"
  Events       = %w(open message close)
  if ENV['RACK_ENV'] == 'production'
    AppHost    = "tcpws.herokuapp.com"
  else
    AppHost    = "heroku.app"
  end
  Config       = {
    listen: {
      ws: "ws://#{AppHost}/client",
      host: "0.0.0.0",
      port: ENV["CLIENT_PORT"]
    },
    proxy: {
      ws: "ws://#{AppHost}/server",
      host: "0.0.0.0",
      port: ENV["SERVER_PORT"]
    }
  }

  module Base
  
    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end

    module ClassMethods
      def configure(flag)
        %w(define_method define_singleton_method).each do |config|
          send config, :config, -> {
            @config ||= Config[flag]
          }
        end
      end

      def start
        EM::run { yield }
      end

      def quit(needblk = false)
        blk = -> { 
          yield if block_given?
          EM.stop 
        }
        needblk ? blk : blk.call
      end

      def get(uri, blk = nil)
        http = EM::HttpRequest.new(uri).get
        if block_given?
          http.callback { yield(http) }
        elsif blk.is_a? Proc
          http.callback {
            if blk.arity == 0
              blk.call
            elsif blk.arity == 1
              blk.call(http)
            end
          }
        else
          http
        end
      end

      def listen(host, port)
         EM::start_server host, port, self
         puts "listen on #{host}:#{port}"
      end
    end
    
    module InstanceMethods


    attr_reader :ws

      def connect(*args)
        if args.count == 1
          Faye::WebSocket::Client.new(*args)
        else
           EM.connect(*args)
        end
      end

      def start
        klass.start { yield }
      end

      def quit(force = false)
        if block_given?
          klass.quit(force) { yield }
        else
          klass.quit(force)
        end
      end

      def open
        ->(e) { puts "#{this}#open" }
      end

      def close
        ->(e) { puts "#{this}#close" }
      end

      private

      def klass
        @klass ||= TcpWs.const_get(this)
      end

      def this
        if @this.nil?
          m = self.class.to_s.match(/TcpWs::(\w+):*/)
          if m
            @this ||= m[1]
          else
            @this ||= self.class.to_s
          end
        else
          @this
        end
      end

    end

  end

end