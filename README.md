# Pubtune

Pubtune is a self-hosted tunneling service - similar to ngrok, but running on your own server. It exposes your local application to the internet via a public URL.

## How It Works

```
Browser → rwqsgqk3.mfakhriddin.uz → Pubtune Server → WebSocket → Client → localhost:PORT
```

1. The client connects to the Pubtune server via WebSocket
2. Incoming requests are forwarded through the tunnel to the client
3. The client proxies them to the local port and returns the response

## Tech Stack

- **Ruby on Rails 8** - main server
- **Faye WebSocket** - real-time tunnel connection
- **PostgreSQL** - database
- **Devise** - authentication
- **Nginx** - reverse proxy
- **Cloudflare** - DNS and SSL

## Installation

### Requirements

- Ruby 3.2+
- PostgreSQL
- Node.js

### Setup

```bash
git clone https://github.com/FaxriddinMaxmadiyorov/pubtune
cd pubtune
bundle install
```

Add the following to `config/application.yml`:

```yaml
DB_USERNAME: "DB_USERNAME"
DB_PASSWORD: "DB_PASSWORD"
```

Create and migrate the database:

```bash
rails db:create db:migrate
```

Start the server:

```bash
rails server
```

## Usage

### 1. Create an account

Go to `https://mfakhriddin.uz` and sign up.

### 2. Create a tunnel

Dashboard → "New Tunnel" → enter a port → copy your token.

### 3. Download the client

Click "Download Client" on the dashboard, or:

```bash
curl -O https://mfakhriddin.uz/pubtune_client.rb
```

### 4. Run the client

```bash
ruby pubtune_client.rb \
  --token YOUR_TOKEN \
  --port YOUR_LOCAL_PORT \
  --server wss://mfakhriddin.uz/ws
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--token` | Tunnel token (required) | - |
| `--port` | Local port to expose | `3000` |
| `--server` | WebSocket server URL | `wss://mfakhriddin.uz/ws` |

### Example

```bash
# Expose a local app running on port 1999
ruby pubtune_client.rb --token abc123 --port 1999

# [Pubtune] Connecting to server: wss://mfakhriddin.uz/ws
# [Pubtune] Connected - authenticating...
# [Pubtune] Successfully connected!
# [Pubtune] Public URL: https://rwqsgqk3.mfakhriddin.uz
# [Pubtune] Local:      http://localhost:1999
```

## Server Deployment (GCP)

### Nginx Configuration

```nginx
server {
    listen 443 ssl;
    server_name *.mfakhriddin.uz;

    ssl_certificate /etc/ssl/cloudflare.crt;
    ssl_certificate_key /etc/ssl/cloudflare.key;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }
}
```

### Firewall

Open the following ports on GCP:
- `80` - HTTP
- `443` - HTTPS

### SSL

Uses a Cloudflare Origin Certificate with wildcard coverage for `*.mfakhriddin.uz`.

## Architecture

```
┌─────────────┐     HTTPS      ┌───────────────┐    WebSocket   ┌──────────────┐
│   Browser   │ ─────────────► │     Nginx      │ ─────────────► │ Rails Server │
└─────────────┘                └───────────────┘                └──────┬───────┘
                                                                        │
                                                                  TunnelRegistry
                                                                        │
┌─────────────┐    WebSocket   ┌───────────────┐                        │
│ Local Server│ ◄────────────► │Pubtune Client │ ◄──────────────────────┘
└─────────────┘                └───────────────┘
```

## License

MIT
