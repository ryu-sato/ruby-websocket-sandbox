require 'websocket-eventmachine-client'
require "json-rpc-objects/v20/request"
require "json-rpc-objects/request"
require "json-rpc-objects/response"
require 'timeout'


def sleep_until(timeout_sec = 30, &_)
    Timeout.timeout(timeout_sec) do
        until yield do
            sleep 0.1
        end
    end
end

class WS
    def initialize
        @ws = nil
        @connection_initialized = nil
    end

    def connection_initialized?
        @connection_initialized
    end

    def connect(uri)
        Thread.start do
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
        @ws.send(data)
    end

    private

    def message_handler(data, type)
        # nothing to do
    end

end

class JSONRPConWS < WS

    class Response
        ACCESS_METHODS = %w[[] []= delete].freeze

        def initialize
            @mutex = Mutex.new
            @data = {}
        end

        ACCESS_METHODS.each do |method|
            define_method(method) do |*args|
                @mutex.synchronize do
                    @data.public_send(method, *args)
                end
            end
        end
    end

    def initialize
        @response = Response.new
    end

    def send(data)
        parsed_data = JsonRpcObjects::Request::parse(data)
        parsed_data.check!

        super(data)

        parsed_data
    end

    def send_and_wait_response(data)
        parsed_data = send(data)
        sleep_until { @response[parsed_data.id] }

        @response.delete(parsed_data.id)
    end

    private

    def message_handler(data, type)
        parsed_data = JsonRpcObjects::Response::parse(data)
        parsed_data.check!

        @response[parsed_data.id] = parsed_data.result
    end

end

ws = JSONRPConWS.new
ws.connect_sync('ws://localhost:8888')

rpc_json_data = JsonRpcObjects::V20::Request::create(:subtract, ["1", "2"], :id => "a2b3")
p ws.send_and_wait_response(rpc_json_data.serialize)
