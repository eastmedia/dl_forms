# class LabeledBuilder < ActionView::Helpers::FormBuilder
#   def self.create_labeled_field(method_name)
#    define_method(%(labeled_#{method_name})) do |label, *args|
#    @template.content_tag("label",
#                          label.to_s.humanize,
#                          :for => %(#{@object_name}_#{label})) +
#      self.send(method_name.to_sym, label, *args)
#    end
#   end
# 
#   field_helpers.each do |name|
#    create_labeled_field(name)
#   end
# end
# 
# # helpers/builder_helper.rb
# module BuilderHelper
#    def labeled_form_for(name, *args, &block)
#      options = args.last.is_a?(Hash) ? args.pop : { }
#      options = options.merge(:builder => LabeledBuilder)
#      args = (args << options)
#      form_for(name, *args, &block)
#    end
# end

# <dt<%= ' class="error"' if f.object.errors.any? %>>
#   <label for="email_address">Email</label>
#   <span class="required">*</span>
# </dt>
# <% for error in f.object.errors %>
#   <dt class="error msg"><%=h error.last %></li>
# <% end %>
# <dd><%= f.text_field :email, :class => "text", :maxlength => 100 %></dd>

module LabeledFormHelper
  # def secure_form_tag(*form_tag_params, &block)
  #   @res = <<-EOF
  #     #{form_for(*form_tag_params)} do |f|
  #     #{capture(&block)}
  #     #{hidden_field_tag('session_id_validation', 'asdf')}
  #     </form>
  #   EOF
  #   eval '_erbout.concat @res', block
  # end
  
  # [:form_for, :fields_for, :form_remote_for, :remote_form_for].each do |meth|
  #   src = <<-end_src
  #     def dl_#{meth}(*form_tag_params, &proc)
  #       @res = <<-code
  #         \#{#{meth}(*form_tag_params)} do
  #           FOO
  #           \#{capture(&proc)}
  #           BAR
  #         end
  #       code
  #       eval '_erbout.concat @res', proc
  #     end
  #   end_src
  #   module_eval src, __FILE__, __LINE__
  # end

  # Returns a label tag that points to a specified attribute (identified by +method+) on an object assigned to a template
  # (identified by +object+).  Additional options on the input tag can be passed as a hash with +options+.  An alternate
  # text label can be passed as a 'text' key to +options+.
  # Example (call, result).
  #   label_for('post', 'category')
  #     <label for="post_category">Category</label>
  # 
  #   label_for('post', 'category', 'text' => 'This Category')
  #     <label for="post_category">This Category</label>
  def label_for(object_name, method, options = {})
    ActionView::Helpers::InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_label_tag(options)
  end

  # Creates a label tag.
  #   label_tag('post_title', 'Title')
  #     <label for="post_title">Title</label>
  def label_tag(name, text, options = {})
    content_tag('label', text, { 'for' => name }.merge(options.stringify_keys))
  end
end

module LabeledInstanceTag
  def to_label_tag(options = {})
    options = options.stringify_keys
    add_default_name_and_id(options)
    options.delete('name')
    options['for'] = options.delete('id')
    content_tag 'label', options.delete('text') || @method_name.humanize, options
  end
end

module FormBuilderMethods
  def label_for(method, options = {})
    @template.label_for(@object_name, method, options.merge(:object => @object))
  end
end

class ActionView::Helpers::FormBuilder
  (%w(date_select) +
   ActionView::Helpers::FormHelper.instance_methods - 
   %w(label_for hidden_field radio_button form_for fields_for)).each do |selector|
    src = <<-end_src
      def dl_#{selector}(method, options = {})
        if object.respond_to?(:errors) && object.errors.respond_to?(:on) && object.errors.on(method)
          output = @template.content_tag('dt', label_for(method, options.block(:required)) + required_label(options[:required]), :class => "error")
          Array(object.errors.on(method)).each do |error|
            output += @template.content_tag('dt', error, :class => "error msg")
          end
          output + @template.content_tag('dd', #{selector}(method, options.block(:required)), :class => "error")
        else
          @template.content_tag('dt', label_for(method, options.block(:required)) + required_label(options[:required])) +
          @template.content_tag('dd', #{selector}(method, options.block(:required)))
        end
      end
    end_src
    class_eval src, __FILE__, __LINE__
  end

  # def radio_button(method, tag_value, options = {})
  #   @template.content_tag('p', label_for(method) + "<br />" + super)
  # end
  
  def dl_file_field(method, options = {})
    if object.respond_to?(:errors) && object.errors.respond_to?(:on) && object.errors.on(method)
      output = @template.content_tag('dt', label_for(method, options.block(:required)) + required_label(options[:required]), :class => "error")
      Array(object.errors.on(method)).each do |error|
        output += @template.content_tag('dt', error, :class => "error msg")
      end
      output + @template.content_tag('dd', file_field(method, options.block(:required)), :id => 'file_field', :class => "error")
    else
      @template.content_tag('dt', label_for(method, options.block(:required)) + required_label(options[:required])) +
      @template.content_tag('dd', file_field(method, options.block(:required)), :id => 'file_field')
    end
  end
  
  def dl_submit(*params)
    @template.content_tag('dt', ' ') +
    @template.content_tag('dd', submit(*params), :class => "buttons")
  end
  
  def dl_select(method, selections, options = {})
    if object.respond_to?(:errors) && object.errors.respond_to?(:on) && object.errors.on(method)
      output = @template.content_tag('dt', label_for(method, options.block(:required, :include_blank)) + required_label(options[:required]), :class => "error")
      Array(object.errors.on(method)).each do |error|
        output += @template.content_tag('dt', error, :class => "error msg")
      end
      output + @template.content_tag('dd', select(method, selections, options), :class => "error")
    else
      @template.content_tag('dt', label_for(method, options.block(:required, :include_blank)) + required_label(options[:required])) +
      @template.content_tag('dd', select(method, selections, options))
    end
  end

  def dl_country_select(method, priority_countries = nil, options = {}, html_options = {})
    @template.content_tag('dt', label_for(method, options.block(:required)) + required_label(options[:required])) +
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

      def tag_with_css(name, options=nil, open=false)
        tag_without_css(name, css_options_for_tag(name, options || {}), open)
      end
      alias_method_chain :tag, :css

      def content_tag_string_with_css(name, content, options)
        content_tag_string_without_css(name, content, css_options_for_tag(name, options || {}))
      end
      alias_method_chain :content_tag_string, :css
    end

    class InstanceTag
      alias_method :tag_without_error_wrapping, :tag_with_css
    end
  end
end
