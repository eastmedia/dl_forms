module LabeledFormHelper
  # Copied from Rails 2.0's #label
  def label_for(object_name, method, options = {})
    ActionView::Helpers::InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_label_tag(options.delete(:text), options)
  end

  # Creates a label tag.
  #   label_tag('post_title', 'Title')
  #     <label for="post_title">Title</label>
  def label_tag(name, text, options = {})
    content_tag('label', text, { 'for' => name }.merge(options.stringify_keys))
  end
end

module LabeledInstanceTag
  # Copied from Rails 2.0
  def to_label_tag(text = nil, options = {})
    name_and_id = options.dup
    add_default_name_and_id(name_and_id)
    options["for"] = name_and_id["id"]
    content = (text.blank? ? nil : text.to_s) || method_name.titleize
    content_tag("label", content, options)
  end
end

module FormBuilderMethods
  def label_for(method, options = {})
    @template.label_for(@object_name, method, options.merge(:object => @object))
  end
end

class ActionView::Helpers::FormBuilder
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper
  
  FORM_FIELDS = %w[date_select] + ActionView::Helpers::FormHelper.instance_methods - %w[label_for hidden_field radio_button form_for fields_for]
  
  FORM_FIELDS.each do |selector|
    src = <<-SRC
      def dl_#{selector}(method, options = {})
        if object.respond_to?(:errors) && object.errors.respond_to?(:on) && object.errors.on(method)
          output = @template.content_tag('dt', label_for(method, options.except(:required)) + required_label(options[:required]), :class => "error")
          Array(object.errors.on(method)).each do |error|
            output += @template.content_tag('dt', error, :class => "error msg")
          end
          output + @template.content_tag('dd', #{selector}(method, options.except(:required)), :class => "error")
        else
          @template.content_tag('dt', label_for(method, options.except(:required, :include_blank, :height, :width, :rows, :cols, :end_year, :start_year, :order)) + required_label(options[:required]), :class => options[:class]) +
          @template.content_tag('dd', #{selector}(method, options.except(:required, :text)), :class => options[:class])
        end
      end
    SRC
    class_eval src, __FILE__, __LINE__
  end

  # Similar to the dl_x form helpers but uses SPAN instead of DL/DT/DD
  FORM_FIELDS.each do |selector|
    src = <<-SRC
      def labeled_#{selector}(method, options = {})
        if object.respond_to?(:errors) && object.errors.respond_to?(:on) && object.errors.on(method)
          output = @template.content_tag(:span, label_for(method, options.except(:required)) + required_label(options[:required]), :class => "error")
          Array(object.errors.on(method)).each do |error|
            output += @template.content_tag(:span, error, :class => "error msg")
          end
          output + #{selector}(method, options.except(:required))
        else
          label_for(method, options.except(:required, :include_blank, :height, :width, :rows, :cols, :end_year, :start_year, :order)) + 
          required_label(options[:required]) +
          #{selector}(method, options.except(:required, :text))
        end
      end
    SRC
    class_eval src, __FILE__, __LINE__
  end
  
  def dl_widgeditor(method, options = {})
    widg_options = options.except(:required, :text, :height, :width).dup.merge(:class => "widgEditor")
    style = []
    style << "height: #{options[:height]};" if options[:height]
    style << "width: #{options[:width]};" if options[:width]
    widg_options[:style] = style.join(" ") unless style.blank?
    
    dd_content = @template.text_area(@object_name, method, widg_options)

    @template.content_tag('dt', label_for(method, options.except(:required, :height, :width, :rows, :cols)) + required_label(options[:required])) + 
    @template.content_tag('dd', dd_content)
  end
  
  # Removes the hidden input field from the rendered output
  def dl_check_box(method, options = {})
    check_box_tag_with_input  = self.send(:check_box, method, options.except(:required))
    check_box_tag_only        = check_box_tag_with_input.gsub(/<input[^>]*type=\"hidden\".*\/>/xi, '')

    if object.respond_to?(:errors) && object.errors.respond_to?(:on) && object.errors.on(method)
      output = @template.content_tag('dt', label_for(method, options.except(:required)) + required_label(options[:required]), :class => "error")
      Array(object.errors.on(method)).each do |error|
        output += @template.content_tag('dt', error, :class => "error msg")
      end
      output + @template.content_tag('dd', check_box_tag_only, :class => "error")
    else
      @template.content_tag('dt', label_for(method, options.except(:required)) + required_label(options[:required])) +
      @template.content_tag('dd', check_box_tag_only)
    end
  end  
  
  def dl_file_uploader(name, options = {})
    dd_content = if (object == object.send(name) && object.respond_to?(:has_uploaded_data?) && object.has_uploaded_data?) || (object != object.send(name) && object.send(name) && object.send(name).id)
      image_link = options[:url] ? options[:url] : @template.send(:static_image_path, object.send(name).id)
      div_content =   @template.link_to(image_tag(image_link), image_link, :class => "image_mask") + "<span class='file_meta'>"
      div_content +=  "File size is: " + @template.send(:h, @template.number_to_human_size(object.send(name).size)).to_s + "</span>"
      div_content +=  @template.link_to_function @template.image_tag("icon_trash.png") + " ", <<-JS
        $('old_#{name}').hide();
        $('#{name}_uploader').appendChild(Builder.node('input', {
            id:   '#{@object_name}_#{name}_uploaded_data',
            name: '#{@object_name}[#{name}_uploaded_data]',
            type: 'file',
            size: '30'
          }));
      JS
      @template.content_tag('div', div_content, :id => "old_#{name}")
    else  
      file_field("#{name}_uploaded_data", options.except(:url))
    end
    
    @template.content_tag('dt', label_for(name, options.except(:url, :required)) + required_label(options[:required])) + 
    @template.content_tag('dd', dd_content, :id => "#{name}_uploader")
  end
  
  def dl_file_field(method, options = {})
    if object.respond_to?(:errors) && object.errors.respond_to?(:on) && object.errors.on(method)
      output = @template.content_tag('dt', label_for(method, options.except(:required)) + required_label(options[:required]), :class => "error")
      Array(object.errors.on(method)).each do |error|
        output += @template.content_tag('dt', error, :class => "error msg")
      end
      output + @template.content_tag('dd', file_field(method, options.except(:required)), :id => 'file_field', :class => "error")
    else
      @template.content_tag('dt', label_for(method, options.except(:required)) + required_label(options[:required])) +
      @template.content_tag('dd', file_field(method, options.except(:required)), :id => 'file_field')
    end
  end
  
  def dl_submit(*params)
    @template.content_tag('dt', ' ') +
    @template.content_tag('dd', submit(*params), :class => "buttons")
  end
  
  def dl_fckeditor(method, options = {})
    options[:toolbarSet] = 'MMH'
    dd_content = @template.fckeditor_textarea(@object_name, method, options.except(:required, :text))

    @template.content_tag('dt', label_for(method, options.except(:required, :toolbarSet)) + required_label(options[:required])) + 
    @template.content_tag('dd', dd_content)
  end
  
  def dl_create_or_update_button(create_cancel_url = nil, update_cancel_url = nil, create_text = nil, update_text = nil)
    dd_content = submit(object.new_record? ? (create_text || "Create") : (update_text || "Update"))
    dd_content += " or "
    
    cancel_url = if object.new_record?
      create_cancel_url
    else
      update_cancel_url
    end
    cancel_url ||= @template.polymorphic_url(object)
    
    dd_content += @template.link_to("Cancel", cancel_url)
    
    @template.content_tag('dt', ' ') +
    @template.content_tag('dd', dd_content, :class => "buttons")
  end
  
  def dl_select(method, selections, options = {}, html_options = {})
    if object.respond_to?(:errors) && object.errors.respond_to?(:on) && object.errors.on(method)
      output = @template.content_tag('dt', label_for(method, options.except(:required, :include_blank, :onchange)) + required_label(options[:required]), :class => "error")
      Array(object.errors.on(method)).each do |error|
        output += @template.content_tag('dt', error, :class => "error msg")
      end
      output + @template.content_tag('dd', select(method, selections, options, html_options), :class => "error")
    else
      @template.content_tag('dt', label_for(method, options.except(:required, :include_blank, :onchange)) + required_label(options[:required])) +
      @template.content_tag('dd', select(method, selections, options, html_options))
    end
  end

  def dl_country_select(method, priority_countries = nil, options = {}, html_options = {})
    @template.content_tag('dt', label_for(method, options.except(:required)) + required_label(options[:required])) +
    @template.content_tag('dd', country_select(method, priority_countries, options, html_options))
  end

  def dl_fields_for(object_name, *args, &proc)
    @template.labeled_fields_for(object_name, *args, &proc)
  end
  
  def required_label(show)
    show ? @template.content_tag(:span, ' *', :class => 'required') : ''
  end
end

ActionView::Base.send                 :include, LabeledFormHelper
ActionView::Helpers::InstanceTag.send :include, LabeledInstanceTag
ActionView::Helpers::FormBuilder.send :include, FormBuilderMethods

module ActionView
  module Helpers
    module TagHelper
      def css_options_for_tag(name, options={})
        name = name.to_sym
        options = options.stringify_keys
        if options.has_key? 'class'
          return options
        elsif name == :input and options['type']
          return options if (options['type'] == 'hidden')
          options['class'] = options['type'].dup
          options['class'] << ' button' if ['submit', 'reset'].include? options['type']
          options['class'] << ' text' if options['type'] == 'password'
        elsif name == :textarea
          options['class'] = 'text'
        end
        options
      end
      
      def tag_with_css(name, options = nil, open = false, escape = true)
        tag_without_css(name, css_options_for_tag(name, options || {}), open, escape)
      end
      alias_method_chain :tag, :css

      def content_tag_string_with_css(name, content, options, escape = true)
        content_tag_string_without_css(name, content, css_options_for_tag(name, options || {}), escape)
      end
      alias_method_chain :content_tag_string, :css
    end

    class InstanceTag
      alias_method :tag_without_error_wrapping, :tag_with_css
    end
  end
end
