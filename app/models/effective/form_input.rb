module Effective
  class FormInput
    attr_accessor :name, :options

    BLANK = ''.html_safe

    delegate :object, :layout, :label, to: :@builder
    delegate :capture, :content_tag, :link_to, to: :@template

    # So this takes in the options for an entire form group.
    def initialize(name, options, builder:, html_options: nil)
      @builder = builder
      @template = builder.template

      @name = name
      @options = extract_options!(options, html_options)
    end

    def input_html_options
      { class: 'form-control' }
    end

    def input_js_options
      {}
    end

    def label_options
      case layout
      when :horizontal
        { class: 'col-sm-2 col-form-label'}
      when :inline
        { class: 'sr-only' }
      else
        { }
      end
    end

    def label_position
      :before
    end

    def feedback_options
      case layout
      when :inline
        false
      else
        { valid: { class: 'valid-feedback' }, invalid: { class: 'invalid-feedback' } }
      end
    end

    def hint_options
      { tag: :small, class: 'form-text text-muted', id: "#{tag_id}_hint" }
    end

    def wrapper_options
      case layout
      when :horizontal
        { class: 'form-group row' }
      else
        { class: 'form-group' }
      end
    end

    def to_html(&block)
      wrap(&block)
    end

    protected

    def wrap(&block)
      case layout
      when :inline
        build_content(&block)
      when :horizontal
        build_wrapper do
          (build_label.presence || content_tag(:div, '', class: 'col-sm-2')) +
          content_tag(:div, build_content(&block), class: 'col-sm-10')
        end
      else # Vertical
        build_wrapper { build_content(&block) }
      end.html_safe
    end

    def build_wrapper(&block)
      content_tag(:div, yield, options[:wrapper])
    end

    def build_content(&block)
      if layout == :horizontal
        build_input(&block) + build_hint + build_feedback
      elsif label_position == :before
        build_label + build_input(&block) + build_hint + build_feedback
      else
        build_input(&block) + build_label + build_hint + build_feedback
      end.html_safe
    end

    def build_label
      return BLANK if options[:label] == false

      text = (options[:label].delete(:text) || object.class.human_attribute_name(name)).html_safe

      if options[:input][:id]
        options[:label][:for] = options[:input][:id]
      end

      label(name, text, options[:label])
    end

    def build_input(&block)
      if has_error? && options[:feedback]
        options[:input][:class] = [options[:input][:class], (has_error?(name) ? 'is-invalid' : 'is-valid')].compact.join(' ')
      end

      if is_required?(name)
        options[:input].reverse_merge!(required: 'required')
      end

      if options[:input][:readonly]
        options[:input][:readonly] = 'readonly'
        options[:input][:class] = options[:input][:class].gsub('form-control', 'form-control-plaintext')
      end

      if options[:hint] && options[:hint][:text] && options[:hint][:id]
        options[:input].reverse_merge!('aria-describedby': options[:hint][:id])
      end

      capture(&block)
    end

    def build_hint
      return BLANK unless options[:hint] && options[:hint][:text]

      tag = options[:hint].delete(:tag)
      text = options[:hint].delete(:text).html_safe

      content_tag(tag, text, options[:hint])
    end

    def build_feedback
      return BLANK if options[:feedback] == false
      return BLANK unless has_error? # Errors anywhere

      if has_error?(name) && options[:feedback][:invalid]
        content_tag(:div, object.errors[name].to_sentence, options[:feedback][:invalid])
      elsif options[:feedback][:valid]
        content_tag(:div, 'Looks good!', options[:feedback][:valid])
      end
    end

    def has_error?(name = nil)
      return false unless object.respond_to?(:errors)
      name ? object.errors[name].present? : object.errors.present?
    end

    def is_required?(name)
      return false unless object && name

      obj = (object.class == Class) ? object : object.class
      return false unless obj.respond_to?(:validators_on)

      obj.validators_on(name).any? { |v| v.kind_of?(ActiveRecord::Validations::PresenceValidator) }
    end

    private

    # Here we split them into { wrapper: {}, label: {}, hint: {}, input: {} }
    # And make sure to keep any additional options on the input: {}
    def extract_options!(options, html_options = nil)
      options.symbolize_keys!
      html_options.symbolize_keys! if html_options

      # effective_bootstrap specific options
      wrapper = options.delete(:wrapper) # Hash
      feedback = options.delete(:feedback) # Hash
      label = options.delete(:label) # String or Hash
      hint = options.delete(:hint) # String or Hash
      input_html = options.delete(:input_html) || {} # Hash
      input_js = options.delete(:input_js) || {} # Hash

      # Every other option goes to input
      @options = input = (html_options || options)

      # Merge all the default objects, and intialize everything
      wrapper = merge_defaults!(wrapper, wrapper_options)
      feedback = merge_defaults!(feedback, feedback_options)
      label = merge_defaults!(label, label_options)
      hint = merge_defaults!(hint, hint_options)

      # Merge input_html: {}, defaults, and add all class: keys together
      input.merge!(input_html.except(:class))
      merge_defaults!(input, input_html_options.except(:class))
      input[:class] = [input[:class], input_html[:class], input_html_options[:class]].compact.join(' ')

      merge_defaults!(input_js, input_js_options)
      input['data-input-js-options'] = JSON.generate(input_js) if input_js.present?

      { wrapper: wrapper, label: label, hint: hint, input: input, feedback: feedback }
    end

    def merge_defaults!(obj, defaults)
      defaults = {} if defaults.nil?

      case obj
      when false
        false
      when nil, true
        defaults
      when String
        defaults.merge(text: obj)
      when Hash
        obj.reverse_merge!(defaults)
      else
        raise 'unexpected object'
      end
    end

    # https://github.com/rails/rails/blob/master/actionview/lib/action_view/helpers/tags/base.rb#L120
    # Not 100% sure best way to generate this
    def tag_id(index = nil)
      case
      when @builder.object_name.empty?
        sanitized_method_name.dup
      when index
        "#{sanitized_object_name}_#{index}_#{sanitized_method_name}"
      else
        "#{sanitized_object_name}_#{sanitized_method_name}"
      end
    end

    def sanitized_object_name
      @builder.object_name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").sub(/_$/, "")
    end

    def sanitized_method_name
      name.to_s.sub(/\?$/, "")
    end

  end
end
