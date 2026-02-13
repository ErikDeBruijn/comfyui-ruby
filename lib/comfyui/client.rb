require "faraday"
require "faraday/multipart"

module ComfyUI
  class Client
    attr_reader :base_url

    def initialize(base_url: nil)
      @base_url = base_url || ComfyUI.base_url
      @client_id = SecureRandom.uuid
    end

    def system_stats
      response = connection.get("/system_stats")
      JSON.parse(response.body)
    end

    def queue_prompt(workflow)
      payload = { prompt: workflow, client_id: @client_id }
      response = connection.post("/prompt") { |req| req.body = payload.to_json }
      parsed = JSON.parse(response.body)

      raise Error, parsed["error"] if parsed["error"]
      raise Error, "No prompt_id returned" unless parsed["prompt_id"]

      parsed["prompt_id"]
    end

    def wait_for_completion(prompt_id)
      deadline = Time.now + ComfyUI.poll_timeout

      loop do
        raise TimeoutError, "Prompt #{prompt_id} timed out after #{ComfyUI.poll_timeout}s" if Time.now > deadline

        history = fetch_history(prompt_id)

        if history&.dig(prompt_id)
          entry = history[prompt_id]
          status = entry.dig("status", "status_str")

          raise Error, "Prompt failed: #{status}" if status == "error"

          return entry["outputs"] if entry["outputs"]&.any?
        end

        sleep ComfyUI.poll_interval
      end
    end

    def fetch_history(prompt_id)
      response = connection.get("/history/#{prompt_id}")
      JSON.parse(response.body)
    end

    def upload_image(data, filename: "input.png", content_type: "image/png")
      io = data.is_a?(String) ? StringIO.new(data) : data
      upload = Faraday::Multipart::FilePart.new(io, content_type, filename)

      upload_conn = Faraday.new(url: base_url) do |f|
        f.request :multipart
        f.response :raise_error
      end

      response = upload_conn.post("/upload/image") do |req|
        req.body = { image: upload, overwrite: "true" }
      end

      parsed = JSON.parse(response.body)
      parsed["name"] || filename
    end

    def download_output(filename, subfolder: "", type: "output")
      response = connection.get("/view") do |req|
        req.params = { filename: filename, subfolder: subfolder, type: type }
      end
      response.body
    end

    private

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.headers["Content-Type"] = "application/json"
        f.options.timeout = 30
        f.options.open_timeout = 10
      end
    end
  end
end
