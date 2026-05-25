class TunnelWebsocketController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def connect
    if Faye::WebSocket.websocket?(request.env)
      ws    = Faye::WebSocket.new(request.env, nil, ping: 15)
      token = nil

      ws.on :message do |event|
        data = JSON.parse(event.data)

        case data["type"]
        when "auth"
          token  = data["token"]
          tunnel = Tunnel.find_by(token: token)

          if tunnel
            TunnelRegistry.instance.register(token, ws)
            tunnel.update!(status: "active")
            ws.send(JSON.dump({ type: "auth_ok", subdomain: tunnel.subdomain }))
          else
            ws.send(JSON.dump({ type: "auth_error", message: "Token noto'g'ri" }))
            ws.close
          end

        when "response"
          PendingRequests.instance.resolve(data["request_id"], data)
        end
      end

      ws.on :close do |_event|
        if token
          TunnelRegistry.instance.unregister(token)
          Tunnel.find_by(token: token)&.update!(status: "inactive")
        end
      end

      ws.rack_response
    else
      head :ok
    end
  end

  def forward
    subdomain = request.host.split(".").first
    tunnel    = Tunnel.find_by(subdomain: subdomain)

    return render plain: "Tunnel topilmadi", status: 404 unless tunnel
    return render plain: "Tunnel nofaol", status: 503 unless TunnelRegistry.instance.active?(tunnel.token)

    request_id   = SecureRandom.hex(8)
    ws_client    = TunnelRegistry.instance.find(tunnel.token)[:ws]

    ws_client.send(JSON.dump({
        type:       "request",
        request_id: request_id,
        method:     request.method,
        path:       request.fullpath,
        headers:    request.headers.env.select { |k, _| k.start_with?("HTTP_") }
                        .transform_keys { |k| k.sub("HTTP_", "").split("_").map(&:capitalize).join("-") },
        body:       request.body.read,
    }))

    response_data = PendingRequests.instance.wait(request_id, timeout: 10)

    if response_data
      headers = response_data["headers"] || {}

      if headers["location"]
        begin
          uri = URI.parse(headers["location"])
          if uri.host
            headers["location"] = "http://#{request.host}:#{request.port}#{uri.path}"
          end
        rescue URI::InvalidURIError
        end
      end

      headers.each { |k, v| response.set_header(k, v) }
      render plain: Base64.strict_decode64(response_data["body"]), status: response_data["status"]
    else
      render plain: "Gateway Timeout", status: 504
    end
  end
end
