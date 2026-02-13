# ComfyUI Ruby Client

Ruby client for the [ComfyUI](https://github.com/comfyanonymous/ComfyUI) API. Includes workflow templates for text-to-image generation (Flux.1-dev) and SVG vectorization (VTracer).

## Installation

```bash
bundle add comfyui --github erikdebruijn/comfyui-ruby
```

## Usage

```ruby
require "comfyui"

ComfyUI.configure do |c|
  c.base_url = "http://comfyui.local:8188"
end

result = ComfyUI.generate_image("a friendly robot icon", width: 512, height: 512, steps: 20)
File.binwrite("output.png", result[:data])

uploaded = ComfyUI.upload_image(result[:data], filename: "robot.png")
svg = ComfyUI.vectorize(uploaded)
File.binwrite("output.svg", svg[:data])
```

## CLI

```bash
comfyui-generate "a rocket ship icon, flat design"
comfyui-vectorize output.png
```

Environment: `COMFYUI_URL`, `OUTPUT_DIR`, `WIDTH`, `HEIGHT`, `STEPS`.

## License

MIT
