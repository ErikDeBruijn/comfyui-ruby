module ComfyUI
  module Workflows
    WORKFLOW_DIR = File.expand_path("workflows", __dir__)

    module_function

    def text_to_image(prompt, width: 512, height: 512, steps: 20, seed: nil)
      template = load("text_to_image")
      seed ||= rand(0..2**32)
      inject(template, "prompt" => prompt, "width" => width, "height" => height, "steps" => steps, "seed" => seed)
    end

    def image_to_svg(image_name)
      template = load("image_to_svg")
      inject(template, "image" => image_name)
    end

    def load(name)
      path = File.join(WORKFLOW_DIR, "#{name}.json")
      raise Error, "Workflow template not found: #{path}" unless File.exist?(path)

      JSON.parse(File.read(path))
    end

    def inject(workflow, params)
      workflow = deep_dup(workflow)

      workflow.each_value do |node|
        next unless node.is_a?(Hash) && node["inputs"]

        title = node.dig("_meta", "title")&.downcase || ""

        params.each do |key, value|
          case key
          when "prompt"
            node["inputs"]["text"] = value if title.include?("clip") || title.include?("prompt")
          when "width"
            node["inputs"]["width"] = value if node["inputs"].key?("width")
          when "height"
            node["inputs"]["height"] = value if node["inputs"].key?("height")
          when "steps"
            node["inputs"]["steps"] = value if node["inputs"].key?("steps")
          when "seed"
            node["inputs"]["seed"] = value if node["inputs"].key?("seed")
            node["inputs"]["noise_seed"] = value if node["inputs"].key?("noise_seed")
          when "image"
            node["inputs"]["image"] = value if node["class_type"]&.include?("LoadImage")
          end
        end
      end

      workflow
    end

    def deep_dup(obj)
      case obj
      when Hash then obj.transform_values { |v| deep_dup(v) }
      when Array then obj.map { |v| deep_dup(v) }
      else obj
      end
    end
  end
end
