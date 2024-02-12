require 'websocket/driver'

module Connection
  def initialize
    @driver = WebSocket::Driver.client(self)

    @driver.on :connect, -> (event) do
      if WebSocket::Driver.websocket?(@driver.env)
        @driver.start
      else
        # handle other HTTP requests, for example
        body = '<h1>hello</h1>'
        response = [
          'HTTP/1.1 200 OK',
          'Content-Type: text/plain',
          "Content-Length: #{body.bytesize}",
          '',
          body
        ]
        send_data response.join("\r\n")
      end
    end

    @driver.on :message, -> (e) { @driver.text(e.data) }
    @driver.on :close,   -> (e) { close_connection_after_writing }
  end

  def receive_data(data)
    @driver.parse(data)
  end

  def write(data)
    send_data(data)
  end
end

EM.run {
  EM.start_server('127.0.0.1', 4180, Connection)
}
