require_relative "lib/comfyui/version"

Gem::Specification.new do |spec|
  spec.name = "comfyui"
  spec.version = ComfyUI::VERSION
  spec.authors = ["Erik de Bruijn"]
  spec.email = ["erik@erikdebruijn.nl"]

  spec.summary = "Ruby client for ComfyUI image generation API"
  spec.description = "A Ruby client for the ComfyUI API with workflow templates for text-to-image generation (Flux.1-dev) and SVG vectorization (VTracer)."
  spec.homepage = "https://github.com/erikdebruijn/comfyui-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob("{lib,exe}/**/*") + %w[comfyui.gemspec Gemfile LICENSE.txt README.md]
  spec.bindir = "exe"
  spec.executables = Dir.glob("exe/*").map { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
end
