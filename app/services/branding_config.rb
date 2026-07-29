class BrandingConfig
  include Rails.application.routes.url_helpers

  attr_reader :account

  GLOBAL_KEYS = %w[
    INSTALLATION_NAME
    BRAND_NAME
    BRAND_URL
    WIDGET_BRAND_URL
    TERMS_URL
    PRIVACY_URL
    LOGO
    LOGO_DARK
    LOGO_THUMBNAIL
  ].freeze

  def initialize(account:, global_config: nil)
    @account = account
    @global_config = global_config || GlobalConfig.get(*GLOBAL_KEYS)
  end

  def installation_name
    value_for('INSTALLATION_NAME', account&.branding_installation_name)
  end

  def brand_name
    value_for('BRAND_NAME', account&.branding_name)
  end

  def brand_url
    value_for('BRAND_URL', account&.branding_brand_url)
  end

  def widget_brand_url
    value_for('WIDGET_BRAND_URL', account&.branding_widget_brand_url)
  end

  def terms_url
    value_for('TERMS_URL', account&.branding_terms_url)
  end

  def privacy_url
    value_for('PRIVACY_URL', account&.branding_privacy_url)
  end

  def primary_color
    account&.branding_primary_color.presence
  end

  def logo
    attachment_url_or_global(account&.logo, 'LOGO')
  end

  def logo_dark
    attachment_url_or_global(account&.logo_dark, 'LOGO_DARK')
  end

  def logo_thumbnail
    attachment_url_or_global(account&.logo_thumbnail, 'LOGO_THUMBNAIL')
  end

  def to_global_config_hash
    {
      'INSTALLATION_NAME' => installation_name,
      'BRAND_NAME' => brand_name,
      'BRAND_URL' => brand_url,
      'WIDGET_BRAND_URL' => widget_brand_url,
      'TERMS_URL' => terms_url,
      'PRIVACY_URL' => privacy_url,
      'PRIMARY_COLOR' => primary_color,
      'LOGO' => logo,
      'LOGO_DARK' => logo_dark,
      'LOGO_THUMBNAIL' => logo_thumbnail
    }.compact
  end

  private

  def value_for(global_key, account_value)
    account_value.presence || @global_config[global_key]
  end

  def attachment_url_or_global(attachment, global_key)
    if attachment&.attached?
      url_for(attachment)
    else
      @global_config[global_key]
    end
  end
end
