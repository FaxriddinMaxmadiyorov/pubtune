class PendingRequests
  include Singleton

  def initialize
    @requests = {}
    @mutex    = Mutex.new
  end

  def wait(request_id, timeout: 10)
    queue = Queue.new

    @mutex.synchronize do
        @requests[request_id] = queue
    end

    begin
        Timeout.timeout(timeout) { queue.pop }
    rescue Timeout::Error
        nil
    ensure
        @mutex.synchronize do
        @requests.delete(request_id)
        end
    end
  end

  def resolve(request_id, data)
    @mutex.synchronize do
      queue = @requests[request_id]
      queue&.push(data)
    end
  end
end
