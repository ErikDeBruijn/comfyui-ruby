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

    def generate_image(prompt, width: 512, height: 512, steps: 20, seed: nil)
      workflow = Workflows.text_to_image(prompt, width: width, height: height, steps: steps, seed: seed)
      prompt_id = queue_prompt(workflow)
      outputs = wait_for_completion(prompt_id)

      image_output = find_image_output(outputs)
      raise Error, "No image output found" unless image_output

      data = download_output(
        image_output["filename"],
        subfolder: image_output["subfolder"] || "",
        type: image_output["type"] || "output"
      )

      { filename: image_output["filename"], data: data, content_type: "image/png" }
    end

    def vectorize(image_name)
      workflow = Workflows.image_to_svg(image_name)
      prompt_id = queue_prompt(workflow)
      outputs = wait_for_completion(prompt_id)

      svg_output = find_svg_output(outputs)
      raise Error, "No SVG output found" unless svg_output

      data = download_output(
        svg_output["filename"],
        subfolder: svg_output["subfolder"] || "",
        type: svg_output["type"] || "output"
      )

      { filename: svg_output["filename"], data: data, content_type: "image/svg+xml" }
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

    def download_output(filename, subfolder: "", type: "output")
      response = connection.get("/view") do |req|
        req.params = { filename: filename, subfolder: subfolder, type: type }
      end
      response.body
    end

    private

    def find_image_output(outputs)
      outputs.each_value do |node_output|
        images = node_output["images"]
        return images.first if images&.any?
      end
      nil
    end

    def find_svg_output(outputs)
      outputs.each_value do |node_output|
        if node_output["saved_svg"]
          filename = node_output["saved_svg"]
          filename = filename.join if filename.is_a?(Array)
          return { "filename" => filename, "subfolder" => "", "type" => "output" }
        end

        %w[svg files images].each do |key|
          files = node_output[key]
          next unless files.is_a?(Array) && files.any?

          svg = files.find { |f| f["filename"]&.end_with?(".svg") }
          return svg if svg
          return files.first
        end
      end
      nil
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.headers["Content-Type"] = "application/json"
        f.options.timeout = 30
        f.options.open_timeout = 10
      end
    end
  end
end
