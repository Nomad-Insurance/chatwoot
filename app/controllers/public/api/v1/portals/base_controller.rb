class Public::Api::V1::Portals::BaseController < PublicController
  include SwitchLocale

  before_action :authorize_portal_host
  before_action :load_public_article
  before_action :show_plain_layout
  before_action :set_color_scheme
  before_action :set_global_config
  around_action :set_locale
  after_action :allow_iframe_requests

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  helper_method :canonical_url

  PORTAL_LAYOUTS = %w[classic documentation].freeze

  private

  def show_plain_layout
    @is_plain_layout_enabled = params[:show_plain_layout] == 'true'
  end

  def set_color_scheme
    @theme_from_params = params[:theme] if %w[dark light].include?(params[:theme])
  end

  def set_portal_layout
    @portal_layout = PORTAL_LAYOUTS.include?(@portal&.layout) ? @portal.layout : 'classic'
  end

  def set_view_variant
    request.variant = :documentation if @portal_layout == 'documentation' && !@is_plain_layout_enabled
  end

  def portal
    @portal ||= Portal.find_by!(slug: params[:slug], archived: false)
  end

  def authorize_portal_host
    portal
    @portal_host_policy = PortalHostPolicy.new(@portal)
    return if @portal_host_policy.allowed?(request.host)

    origin = @portal_host_policy.canonical_origin
    if origin && published_page?
      redirect_to "#{origin}#{request.path}", status: :moved_permanently, allow_other_host: true
    else
      head :not_found
    end
  end

  # Only existing public HTML pages qualify for migration redirects.
  # Previews, searches, API responses and tracking requests never redirect.
  def published_page?
    return false unless action_name == 'show' && request.format.html?
    return @portal.articles.published.exists?(slug: params[:article_slug]) if params[:article_slug].present?
    return public_category? if params[:category_slug].present?

    params[:locale].blank? || @portal.public_locale_codes.include?(params[:locale])
  end

  def public_category?
    @portal.categories.exists?(slug: params[:category_slug], locale: params[:locale])
  end

  def load_public_article
    return if params[:article_slug].blank?

    @article = @portal.articles.published.find_by!(slug: params[:article_slug])
  end

  def canonical_url
    return unless published_page?

    "#{@portal_host_policy.public_origin(request)}#{request.path}"
  end

  def set_locale(&)
    locale = params[:locale].presence || @article&.category&.locale || @article&.locale || @portal.default_locale
    @locale = validate_and_get_locale(locale)
    I18n.with_locale(@locale, &)
  end

  def allow_iframe_requests
    response.headers.delete('X-Frame-Options') if @is_plain_layout_enabled
  end

  def render_404
    portal
    render 'public/api/v1/portals/error/404', status: :not_found
  end

  def set_global_config
    portal
    branding = BrandingConfig.new(account: @portal.account).to_global_config_hash
    @global_config = branding.slice(
      'LOGO_THUMBNAIL',
      'BRAND_NAME',
      'BRAND_URL',
      'INSTALLATION_NAME'
    )
  end
end
