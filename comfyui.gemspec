require_relative "lib/comfyui/version"

Gem::Specification.new do |spec|
  spec.name = "comfyui"
  spec.version = ComfyUI::VERSION
  spec.authors = ["Erik de Bruijn"]
  spec.email = ["erik@erikdebruijn.nl"]

  spec.summary = "Ruby client for the ComfyUI API"
  spec.description = "A thin Ruby client for the ComfyUI REST API. Queue workflows, poll for completion, upload images, and download outputs."
  spec.homepage = "https://github.com/erikdebruijn/comfyui-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob("lib/**/*") + %w[comfyui.gemspec Gemfile LICENSE.txt README.md CONTRIBUTING.md]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
end
