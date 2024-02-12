require 'websocket-eventmachine-client'
require "json-rpc-objects/v20/request"
require "json-rpc-objects/request"
require 'timeout'

class WS
    def initialize
        @response = {}
        Thread.new do
            EM.run do
                @ws = WebSocket::EventMachine::Client.connect(:uri => 'ws://localhost:8888')

                @ws.onopen do
                    puts "Connected"
                end

                @ws.onmessage do |data, type|
                    puts "Received message: #{data}, type: #{type}"

                    parsed_data = JsonRpcObjects::Request::parse(data)
                    parsed_data.check!

                    @response[parsed_data.id] = data
                end

                @ws.onclose do |code, reason|
                    puts "Disconnected with status code: #{code}"
                end

                @initialized = true
            end
        end
    end

    def self.initialize_sync
        this = new
        Timeout.timeout(30) do
            while !this.initialized? do
                sleep 0.1
            end
        end

        this
    end

    def initialized?
        @initialized
    end

    def send_sync(data)
        parsed_data = JsonRpcObjects::Request::parse(data)
        parsed_data.check!

        @ws.send(data)

        Timeout.timeout(30) do
            while !@response[parsed_data.id]
                sleep 1
            end
        end

        @response.delete(parsed_data.id)
    end
end

ws = WS.initialize_sync

rpc_json_data = JsonRpcObjects::V20::Request::create(:subtract, ["1", "2"], :id => "a2b3")
ws.send_sync(rpc_json_data.serialize)
