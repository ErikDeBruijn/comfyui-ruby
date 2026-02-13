require "json"
require "securerandom"

module ComfyUI
  class Error < StandardError; end
  class TimeoutError < Error; end

  class << self
    attr_writer :base_url, :poll_interval, :poll_timeout

    def base_url
      @base_url || ENV.fetch("COMFYUI_URL", "http://comfyui.local:8188")
    end

    def poll_interval
      @poll_interval || 2
    end

    def poll_timeout
      @poll_timeout || 300
    end

    def configure
      yield self
    end

    def client
      @client ||= Client.new
    end

    def reset_client!
      @client = nil
    end

    def queue_prompt(...) = client.queue_prompt(...)
    def wait_for_completion(...) = client.wait_for_completion(...)
    def upload_image(...) = client.upload_image(...)
    def download_output(...) = client.download_output(...)
    def fetch_history(...) = client.fetch_history(...)
    def system_stats = client.system_stats
  end
end

require_relative "comfyui/version"
require_relative "comfyui/client"
