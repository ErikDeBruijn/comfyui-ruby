# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'socket'
require 'websocket'

module ComfyUI
  class Client
    attr_reader :base_url

    def initialize(base_url: nil)
      @base_url = base_url || ComfyUI.base_url
      @client_id = SecureRandom.uuid
    end

    def system_stats
      response = connection.get('/system_stats')
      JSON.parse(response.body)
    end

    def queue_prompt(workflow)
      payload = { prompt: workflow, client_id: @client_id }
      response = connection.post('/prompt') { |req| req.body = payload.to_json }
      parsed = JSON.parse(response.body)

      raise Error, parsed['error'] if parsed['error']
      raise Error, 'No prompt_id returned' unless parsed['prompt_id']

      parsed['prompt_id']
    end

    def wait_for_completion(prompt_id, &block)
      if block
        wait_via_websocket(prompt_id, &block)
      else
        wait_via_polling(prompt_id)
      end
    end

    def fetch_history(prompt_id)
      response = connection.get("/history/#{prompt_id}")
      JSON.parse(response.body)
    end

    def upload_image(data, filename: 'input.png', content_type: 'image/png')
      io = data.is_a?(String) ? StringIO.new(data) : data
      upload = Faraday::Multipart::FilePart.new(io, content_type, filename)

      upload_conn = Faraday.new(url: base_url) do |f|
        f.request :multipart
        f.response :raise_error
      end

      response = upload_conn.post('/upload/image') do |req|
        req.body = { image: upload, overwrite: 'true' }
      end

      parsed = JSON.parse(response.body)
      parsed['name'] || filename
    end

    def download_output(filename, subfolder: '', type: 'output')
      response = connection.get('/view') do |req|
        req.params = { filename: filename, subfolder: subfolder, type: type }
      end
      response.body
    end

    private

    def wait_via_websocket(prompt_id, &block)
      uri = URI.parse(base_url)
      ws_url = "ws://#{uri.host}:#{uri.port}/ws?clientId=#{@client_id}"
      start_time = Time.zone.now
      deadline = start_time + ComfyUI.poll_timeout
      socket = nil

      socket = TCPSocket.new(uri.host, uri.port)
      handshake = WebSocket::Handshake::Client.new(url: ws_url)
      socket.write(handshake.to_s)

      until handshake.finished?
        raise TimeoutError, 'WebSocket handshake timed out' if Time.zone.now > deadline

        data = socket.readpartial(4096)
        handshake << data
      end
      raise Error, 'WebSocket handshake failed' unless handshake.valid?

      frame_parser = WebSocket::Frame::Incoming::Client.new
      frame_parser << handshake.leftovers if handshake.leftovers.present?

      catch(:completed) do
        loop do
          raise TimeoutError, "Prompt #{prompt_id} timed out after #{ComfyUI.poll_timeout}s" if Time.zone.now > deadline

          ready = IO.select([socket], nil, nil, ComfyUI.poll_interval)
          next unless ready

          data = socket.readpartial(4096)
          frame_parser << data

          while (msg = frame_parser.next)
            next unless msg.type == :text

            parsed = JSON.parse(msg.data)
            handle_ws_message(parsed, prompt_id, start_time, socket, &block)
          end
        end
      end
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT, EOFError, SocketError
      # WebSocket unavailable or closed — fall back to HTTP polling with estimated progress
      wait_via_polling(prompt_id, &block)
    ensure
      begin
        socket&.close
      rescue StandardError
        nil
      end
    end

    def handle_ws_message(parsed, prompt_id, start_time, socket)
      case parsed['type']
      when 'progress'
        pd = parsed['data']
        return unless pd['prompt_id'] == prompt_id

        step = pd['value']
        total = pd['max']
        pct = total.positive? ? (step.to_f / total * 100).round : 0
        yield(step: step, total: total, percent: pct, elapsed: Time.zone.now - start_time)
      when 'executing'
        ed = parsed['data']
        return unless ed['prompt_id'] == prompt_id

        if ed['node'].nil?
          begin
            socket.close
          rescue StandardError
            nil
          end
          throw :completed, fetch_outputs_with_retry(prompt_id)
        else
          yield(node: ed['node'], event: :executing, elapsed: Time.zone.now - start_time)
        end
      when 'execution_error'
        ed = parsed['data']
        return unless ed['prompt_id'] == prompt_id

        begin
          socket.close
        rescue StandardError
          nil
        end
        raise Error, "Prompt failed: #{ed['exception_message'] || 'execution error'}"
      end
    end

    def wait_via_polling(prompt_id, &block)
      deadline = Time.zone.now + ComfyUI.poll_timeout
      start_time = Time.zone.now
      iteration = 0

      loop do
        raise TimeoutError, "Prompt #{prompt_id} timed out after #{ComfyUI.poll_timeout}s" if Time.zone.now > deadline

        history = fetch_history(prompt_id)

        if history&.dig(prompt_id)
          entry = history[prompt_id]
          status = entry.dig('status', 'status_str')

          raise Error, "Prompt failed: #{status}" if status == 'error'

          return entry['outputs'] if entry['outputs']&.any?
        end

        iteration += 1
        block&.call(iteration: iteration, elapsed: Time.zone.now - start_time)

        sleep ComfyUI.poll_interval
      end
    end

    def fetch_outputs_with_retry(prompt_id)
      5.times do
        history = fetch_history(prompt_id)
        if history&.dig(prompt_id)
          entry = history[prompt_id]
          status = entry.dig('status', 'status_str')
          raise Error, "Prompt failed: #{status}" if status == 'error'
          return entry['outputs'] if entry['outputs']&.any?
        end
        sleep 0.5
      end
      raise Error, "Outputs not found after completion for prompt #{prompt_id}"
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.headers['Content-Type'] = 'application/json'
        f.options.timeout = 30
        f.options.open_timeout = 10
      end
    end
  end
end
