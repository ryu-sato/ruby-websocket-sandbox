require 'websocket-eventmachine-client'
require "json-rpc-objects/v20/request"
require "json-rpc-objects/request"

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

    def initialized?
        @initialized
    end

    def send_sync(data)
        parsed_data = JsonRpcObjects::Request::parse(data)
        parsed_data.check!

        @ws.send(data)

        timeout = 30 # seconds
        while !@response[parsed_data.id] || timeout <= 0
            sleep 1
            timeout -= 1
        end
        if timeout <= 0
            puts "Timed out waiting response"
            return nil
        end

        @response.delete(parsed_data.id)
    end
end

ws = WS.new
while !ws.initialized? do
    pp 'ws is nil'
end

rpc_json_data = JsonRpcObjects::V20::Request::create(:subtract, ["1", "2"], :id => "a2b3")
ws.send_sync(rpc_json_data.serialize)

p 'start with sleep 3s...'
sleep(3)
p 'finish'
