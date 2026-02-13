# ComfyUI Ruby Client

Thin Ruby client for the [ComfyUI](https://github.com/comfyanonymous/ComfyUI) REST API. Queue workflows, poll for completion, upload images, download outputs.

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

# Check system status
ComfyUI.system_stats

# Queue any workflow and wait for results
prompt_id = ComfyUI.queue_prompt(workflow_hash)
outputs = ComfyUI.wait_for_completion(prompt_id)

# Upload an image
name = ComfyUI.upload_image(File.binread("input.png"), filename: "input.png")

# Download an output
data = ComfyUI.download_output("output_00001_.png")
```

## Workflows

For ready-made workflow templates (Flux.1-dev text-to-image, VTracer SVG vectorization) see [comfyui-workflows](https://github.com/erikdebruijn/comfyui-workflows).

## License

MIT
