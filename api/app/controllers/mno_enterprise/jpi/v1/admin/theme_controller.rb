require 'rake'

Rake::Task.clear # necessary to avoid tasks being loaded several times in dev mode
Rails.application.load_tasks # load application tasks

module MnoEnterprise
  class Jpi::V1::Admin::ThemeController < Jpi::V1::Admin::BaseResourceController
    # No xsrf
    skip_before_filter :verify_authenticity_token

    # POST /mnoe/jpi/v1/admin/theme/save
    def save
      if params[:publish]
        # Recompile style for production use
        apply_previewer_style(params[:theme])
        publish_style
      else
        # Save and rebuild previewer style only
        # (so it is kept across page reloads)
        save_previewer_style(params[:theme])
        rebuild_previewer_style
      end
      SystemManager.publish_assets
      render json: {status:  'Ok'},  status: :created
    end

    # POST /mnoe/jpi/v1/admin/theme/reset
    def reset
      if params[:default] == true
        reset_default_style
        publish_style
      else
        reset_previewer_style
      end
      rebuild_previewer_style
      SystemManager.publish_assets
      render json: {status:  'Ok'}
    end

    # POST /mnoe/jpi/v1/admin/theme/logo
    def logo
      logo_content = params[:logo].read
      [
        'frontend/src/images/main-logo.png',
        'public/dashboard/images/main-logo.png',
        'public/admin/images/main-logo.png',
        'app/assets/images/mno_enterprise/main-logo.png'
      ].each do |filepath|
        FileUtils.mkdir_p(File.dirname(Rails.root.join(filepath)))
        File.open(Rails.root.join(filepath),'wb') { |f| f.write(logo_content) }
      end
      recompile_assets
      SystemManager.publish_assets
      # Need to restart in non dev to get the new precompiled assets
      SystemManager.restart unless Rails.env.development?
      render json: {status:  'Ok'},  status: :created
    end

    #=====================================================
    # Protected
    #=====================================================
    protected

      # Save current style to theme-previewer-tmp.less stylesheet
      # This file overrides theme-previewer-published.less
      def save_previewer_style(theme)
        target = Rails.root.join('frontend', 'src','app','stylesheets','theme-previewer-tmp.less')
        File.open(target, 'w') { |f| f.write(theme_to_less(theme)) }
      end

      # Save style to theme-previewer-published.less and discard theme-previewer-tmp.less
      def apply_previewer_style(theme)
        target = Rails.root.join('frontend', 'src','app','stylesheets','theme-previewer-published.less')
        File.open(target, 'w') { |f| f.write(theme_to_less(theme)) }
        reset_previewer_style
      end

      # Reset previewer style to the published style (ie: delete saved style)
      def reset_previewer_style
        target = Rails.root.join('frontend', 'src','app','stylesheets','theme-previewer-tmp.less')
        File.exist?(target) && File.delete(target)
      end

      # Reset to default style: delete saved and published style
      def reset_default_style
        reset_previewer_style
        target = Rails.root.join('frontend', 'src','app','stylesheets','theme-previewer-published.less')
        File.exist?(target) && File.truncate(target, 0)
      end

      def rebuild_previewer_style
        Rake::Task['mnoe:frontend:previewer:save'].reenable
        Rake::Task['mnoe:frontend:previewer:save'].invoke
      end

      def publish_style
        Rake::Task['mnoe:frontend:previewer:build'].reenable
        Rake::Task['mnoe:frontend:previewer:build'].invoke
      end

      # TODO: remove once devise pages have been extracted and we remove the asset pipeline
      def recompile_assets
        Rake::Task['assets:precompile'].reenable
        Rake::Task['assets:precompile'].invoke
      end

      # Convert a theme provided as a hash into a properly
      # formatted LESS file
      def theme_to_less(theme)
        out = "// Generated by the Express Theme Previewer\n"

        if theme[:branding]
          out += "\n//----------------------------------------\n"
          out += "// General Branding\n"
          out += "//----------------------------------------\n"
          out += theme[:branding].map { |k,v| "#{k}: #{v};" }.join("\n")
          out += "\n"
        end

        if theme[:variables]
          out += "\n//----------------------------------------\n"
          out += "// Theme Variables\n"
          out += "//----------------------------------------\n"
          theme[:variables].each do |section,vars|
            out += "// #{section}\n"
            out += vars.map { |k,v| "#{k}: #{v};" }.join("\n")
            out += "\n\n"
          end
        end

        return out
      end
  end
end
