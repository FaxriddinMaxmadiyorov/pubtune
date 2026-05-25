require 'faye/websocket'
require 'eventmachine'
require 'net/http'
require 'json'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.on("--token TOKEN", "Tunnel token") { |v| options[:token] = v }
  opts.on("--port PORT", Integer, "Local port") { |v| options[:port] = v }
  opts.on("--server SERVER", "Server URL") { |v| options[:server] = v }
end.parse!

TOKEN      = options[:token]  || ENV["PUBTUNE_TOKEN"]
LOCAL_PORT = options[:port]   || 3000
SERVER_URL = options[:server] || "wss://pubtune.io/ws"

abort "Token kerak! --token TOKEN" unless TOKEN

class PubtuneClient
  def initialize(token, local_port, server_url)
    @token      = token
    @local_port = local_port
    @server_url = server_url
    @ws         = nil
    @reconnect  = true
  end

  def start
    puts "\e[32m[Pubtune]\e[0m Serverga ulanmoqda: #{@server_url}"

    EM.run do
      connect
    end
  end

  private

  def connect
    @ws = Faye::WebSocket::Client.new(@server_url)

    @ws.on :open do |_event|
      puts "\e[32m[Pubtune]\e[0m Ulandi — autentifikatsiya..."
      @ws.send(JSON.dump({ type: "auth", token: @token }))
    end

    @ws.on :message do |event|
      data = JSON.parse(event.data)
      handle_message(data)
    end

    @ws.on :close do |event|
      puts "\e[33m[Pubtune]\e[0m Uzildi (#{event.code})"
      if @reconnect
        puts "\e[33m[Pubtune]\e[0m 3 soniyada qayta ulanadi..."
        EM.add_timer(3) { connect }
      end
    end

    @ws.on :error do |event|
      puts "\e[31m[Pubtune]\e[0m Xatolik: #{event.message}"
    end
  end

  def handle_message(data)
    case data["type"]
    when "auth_ok"
      puts "\e[32m[Pubtune]\e[0m Muvaffaqiyatli ulandi!"
      puts "\e[32m[Pubtune]\e[0m Public URL: \e[1mhttp://#{data['subdomain']}.pubtune.io\e[0m"
      puts "\e[32m[Pubtune]\e[0m Local:      \e[1mhttp://localhost:#{@local_port}\e[0m"
      puts "\e[90m─────────────────────────────────────────\e[0m"

    when "auth_error"
      puts "\e[31m[Pubtune]\e[0m Auth xatolik: #{data['message']}"
      @reconnect = false
      EM.stop

    when "request"
      handle_request(data)
    end
  end

  def handle_request(data)
    EM.defer do
      begin
        response = forward_to_local(data)
        puts "\e[90m#{Time.now.strftime('%H:%M:%S')}\e[0m \e[32m#{data['method']}\e[0m #{data['path']} → \e[32m#{response[:status]}\e[0m"

        @ws.send(JSON.dump({
          type:       "response",
          request_id: data["request_id"],
          status:     response[:status],
          headers:    response[:headers],
          body:       response[:body],
        }))
      rescue => e
        puts "\e[31m[Pubtune]\e[0m Request xatolik: #{e.message}"
        @ws.send(JSON.dump({
          type:       "response",
          request_id: data["request_id"],
          status:     502,
          headers:    { "Content-Type" => "text/plain" },
          body:       "Bad Gateway: #{e.message}",
        }))
      end
    end
  end

  def forward_to_local(data)
    uri = URI("http://localhost:#{@local_port}#{data['path']}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 10
    http.open_timeout = 5

    request_class = {
      "GET"    => Net::HTTP::Get,
      "POST"   => Net::HTTP::Post,
      "PUT"    => Net::HTTP::Put,
      "PATCH"  => Net::HTTP::Patch,
      "DELETE" => Net::HTTP::Delete,
    }[data["method"]] || Net::HTTP::Get

    req = request_class.new(uri)

    data["headers"]&.each do |key, value|
      req[key] = value unless key.downcase == "host"
    end

    req.body = data["body"] if data["body"] && !data["body"].empty?

    response = http.request(req)

    headers = {}
    response.each_header { |k, v| headers[k] = v }

    {
      status:  response.code.to_i,
      headers: headers,
      body:    response.body.to_s,
    }
  end
end

client = PubtuneClient.new(TOKEN, LOCAL_PORT, SERVER_URL)

trap("INT") do
  puts "\n\e[33m[Pubtune]\e[0m To'xtatildi."
  EM.stop
end

client.start
