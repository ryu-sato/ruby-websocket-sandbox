require 'websocket-eventmachine-client'
require "json-rpc-objects/v20/request"
require "json-rpc-objects/request"
require 'timeout'

class Response
    def initialize
        @mutex = Mutex.new
        @response = {}
    end

    def [](key)
        @mutex.synchronize do
            @response[key]
        end
    end

    def []=(key, value)
        @mutex.synchronize do
            @response[key] = value
        end
    end

    def delete(key)
        @mutex.synchronize do
            @response.delete(key)
        end
    end
end

class WS
    def initialize
        @response = Response.new
        @ws = nil
        @connection_initialized = nil
    end

    def connection_initialized?
        @connection_initialized
    end

    def connect(uri)
        Thread.new do
            EM.run do
                @ws = WebSocket::EventMachine::Client.connect(uri:)
                @ws.onmessage {|data, type| message_handler(data, type) }
                @connection_initialized = true
            end
        end
    end

    def connect_sync(uri)
        connect(uri)
        sleep_until { connection_initialized? }
    end

    def send(data)
        parsed_data = JsonRpcObjects::Request::parse(data)
        parsed_data.check!

        @ws.send(data)

        parsed_data
    end

    def send_sync(data)
        parsed_data = send(data)
        sleep_until { @response[parsed_data.id] }

        @response.delete(parsed_data.id)
    end

    private

    def message_handler(data, type)
        parsed_data = JsonRpcObjects::Request::parse(data)
        parsed_data.check!

        @response[parsed_data.id] = data
    end

    def sleep_until(timeout_sec = 30, &_)
        Timeout.timeout(timeout_sec) do
            until yield do
                sleep 0.1
            end
        end
    end
end

ws = WS.new
ws.connect_sync('ws://localhost:8888')

rpc_json_data = JsonRpcObjects::V20::Request::create(:subtract, ["1", "2"], :id => "a2b3")
ws.send_sync(rpc_json_data.serialize)
