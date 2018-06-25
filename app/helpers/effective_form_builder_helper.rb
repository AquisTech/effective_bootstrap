module EffectiveFormBuilderHelper
  def effective_form_with(**options, &block)
    options[:class] = [options[:class], 'needs-validation', ('form-inline' if options[:layout] == :inline)].compact.join(' ')
    options[:html] = (options[:html] || {}).merge(novalidate: true, onsubmit: 'return EffectiveForm.validate(this);')

    # Compute the default ID
    subject = Array(options[:scope] || options[:model]).last

    html_id = if subject.kind_of?(Symbol)
      subject
    elsif subject.respond_to?(:new_record?) && subject.new_record?
      "new_#{subject.class.name.underscore}"
    elsif subject.respond_to?(:persisted?) && subject.persisted?
      "edit_#{subject.class.name.underscore}_#{subject.to_param}"
    else
      raise 'Unexpected subject. Expected :scope or :model to be a symbol or ActiveRecord object'
    end

    remote_index = options.except(:model).hash.abs

    if options.delete(:remote) == true
      @_effective_remote_index ||= 0

      if options[:html][:data].kind_of?(Hash)
        options[:html][:data][:remote] = true
        options[:html][:data]['data-remote-index'] = remote_index
      else
        options[:html]['data-remote'] = true
        options[:html]['data-remote-index'] = remote_index
      end

      html_id = "#{html_id}_#{remote_index}"
    end

    # Assign default ID
    options[:id] ||= options[:html].delete(:id) || html_id

    without_error_proc do
      form_with(**options.merge(builder: Effective::FormBuilder), &block)
    end
  end

  private

  # Disables a .fields_with_errors wrapping div when
  def without_error_proc
    original = ActionView::Base.field_error_proc

    begin
      ActionView::Base.field_error_proc = proc { |input, _| input }; yield
    ensure
      ActionView::Base.field_error_proc = original
    end
  end

end
