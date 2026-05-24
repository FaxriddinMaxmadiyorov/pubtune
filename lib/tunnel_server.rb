require 'faye/websocket'
require 'json'

class TunnelServer
  KEEPALIVE_TIME = 15

  def initialize(app)
    @app = app
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      handle_websocket(env)
    elsif tunnel_request?(env)
      handle_tunnel_request(env)
    else
      @app.call(env)
    end
  end

  private

  def handle_websocket(env)
    ws    = Faye::WebSocket.new(env, nil, ping: KEEPALIVE_TIME)
    token = nil

    ws.on :message do |event|
      data = JSON.parse(event.data)

      case data["type"]
      when "auth"
        token = data["token"]
        tunnel = Tunnel.find_by(token: token)

        if tunnel
          TunnelRegistry.instance.register(token, ws)
          tunnel.update!(status: "active")
          ws.send(JSON.dump({ type: "auth_ok", subdomain: tunnel.subdomain }))
          Rails.logger.info "[TunnelServer] Client connected: #{token}"
        else
          ws.send(JSON.dump({ type: "auth_error", message: "Token noto'g'ri" }))
          ws.close
        end

      when "response"
        # Client dan javob keldi — pending requestga yuborish
        request_id = data["request_id"]
        PendingRequests.instance.resolve(request_id, data)
      end
    end

    ws.on :close do |_event|
      if token
        TunnelRegistry.instance.unregister(token)
        Tunnel.find_by(token: token)&.update!(status: "inactive")
        Rails.logger.info "[TunnelServer] Client disconnected: #{token}"
      end
    end

    ws.rack_response
  end

  def handle_tunnel_request(env)
    subdomain = extract_subdomain(env)
    tunnel    = Tunnel.find_by(subdomain: subdomain)

    return not_found("Tunnel topilmadi") unless tunnel
    return not_found("Tunnel nofaol") unless TunnelRegistry.instance.active?(tunnel.token)

    # Request ni client ga yuborish
    request_id = SecureRandom.hex(8)
    request_data = build_request_data(env, request_id)

    ws_client = TunnelRegistry.instance.find(tunnel.token)[:ws]
    ws_client.send(JSON.dump(request_data))
    TunnelRegistry.instance.increment_requests(tunnel.token)

    # Javob kutish
    response = PendingRequests.instance.wait(request_id, timeout: 10)

    if response
      [
        response["status"],
        response["headers"] || { "Content-Type" => "text/plain" },
        [response["body"].to_s]
      ]
    else
      [504, { "Content-Type" => "text/plain" }, ["Gateway Timeout"]]
    end
  end

  def tunnel_request?(env)
    host = env["HTTP_HOST"].to_s
    host.end_with?(".pubtune.io") || host.include?(".localhost")
  end

  def extract_subdomain(env)
    host = env["HTTP_HOST"].to_s
    host.split(".").first
  end

  def build_request_data(env, request_id)
    request = Rack::Request.new(env)
    {
      type:       "request",
      request_id: request_id,
      method:     request.request_method,
      path:       request.fullpath,
      headers:    extract_headers(env),
      body:       request.body.read,
    }
  end

  def extract_headers(env)
    env.select { |k, _| k.start_with?("HTTP_") }
       .transform_keys { |k| k.sub("HTTP_", "").split("_").map(&:capitalize).join("-") }
  end

  def not_found(msg)
    [404, { "Content-Type" => "text/plain" }, [msg]]
  end
end
