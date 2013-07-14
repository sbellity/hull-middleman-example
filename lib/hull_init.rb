require 'active_support/inflector/inflections'
require 'handlebars_assets'

module Middleman::Renderers::Handlebars
  class << self
    def registered(app)
      app.inst.template_extensions :handlebars => :js, :hls => :js
      ::Tilt.register ::HandlebarsAssets::TiltHandlebars, 'handlebars', 'hbs'
    end
 
    alias :included :registered
  end
end

module HullInit
  class << self
    def app_id
      @config[:app_id]
    end

    def app_secret
      @config[:app_secret]
    end

    def org_url
      @config[:org_url]
    end

    def version
      @config[:version] || 'develop'
    end

    def cdn_host
      @config[:cdn_host] || "https://d3f5pyioow99x0.cloudfront.net"
    end

    def init_config
      (@config[:js_config] || {}).merge({ 
        appId: @config[:app_id],
        orgUrl: @config[:org_url],
        expose: ['require'],
        jsUrl: cdn_host
      })
    end

    def registered(app, config={})
      @config = config.symbolize_keys
      app.helpers Helpers
      app.after_configuration do
      end
      HandlebarsAssets::Config.template_namespace = "Hull.templates"
      HandlebarsAssets::Config.path_prefix = "hull_components"
      ::Middleman::Templates.register :hbs, Middleman::Renderers::Handlebars
      ::Sprockets.register_engine :hbs, HullInit::TiltHandlebars
    end
    alias :included :registered
  end

  class TiltHandlebars < HandlebarsAssets::TiltHandlebars
    def evaluate(scope, locals, &block)
      template_path = TemplatePath.new(scope)

      template_namespace = HandlebarsAssets::Config.template_namespace
      compiled_hbs = HandlebarsAssets::Handlebars.precompile(data, HandlebarsAssets::Config.options)

      <<-TEMPLATE
Hull.require(['handlebars'], function(Handlebars) {
  Hull.templates[#{template_path.name}] = (function() { return #{compiled_hbs} })();
  Handlebars.registerPartial(#{template_path.name.gsub('/', '.')}, Hull.templates[#{template_path.name}]);
  return Hull.templates[#{template_path.name}];
});
      TEMPLATE
    end  
  end

  module Helpers

    def hull_init options={}
      host = (HullInit.cdn_host =~ /^http/ ? HullInit.cdn_host : "//#{HullInit.cdn_host}").gsub(/\/$/, '')
      src = "#{host}/#{options[:version] || HullInit.version}/hull.js"
      <<-CODE
<script src="#{src}"></script>
<script>Hull.init(#{HullInit.init_config.to_json}, function() { console.warn('hull init ok !')});</script>
      CODE
    end

    def hull_component name, options={}
      opts = " " + options.map { |k,v| "data-hull-#{k.to_s.underscore.gsub('_', '-')}='#{v}'" }.join(" ")
      "<div data-hull-widget='#{name}'#{opts}></div>"
    end

  end

end

::Middleman::Extensions.register(:hull_init, HullInit)