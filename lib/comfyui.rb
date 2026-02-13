require "json"
require "securerandom"
require "fileutils"

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

    def generate_image(...) = client.generate_image(...)
    def vectorize(...) = client.vectorize(...)
    def upload_image(...) = client.upload_image(...)
    def system_stats = client.system_stats
  end
end

require_relative "comfyui/version"
require_relative "comfyui/client"
require_relative "comfyui/workflows"
