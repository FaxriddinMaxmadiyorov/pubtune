class TunnelRegistry
  include Singleton

  def initialize
    @tunnels = {}
    @mutex   = Mutex.new
  end

  def register(token, ws)
    @mutex.synchronize do
      @tunnels[token] = {
        ws:         ws,
        connected_at: Time.now,
        requests:   0,
      }
    end
  end

  def unregister(token)
    @mutex.synchronize do
      @tunnels.delete(token)
    end
  end

  def find(token)
    @mutex.synchronize do
      @tunnels[token]
    end
  end

  def active?(token)
    @mutex.synchronize do
      @tunnels.key?(token)
    end
  end

  def increment_requests(token)
    @mutex.synchronize do
      @tunnels[token][:requests] += 1 if @tunnels[token]
    end
  end

  def all
    @mutex.synchronize do
      @tunnels.dup
    end
  end
end
