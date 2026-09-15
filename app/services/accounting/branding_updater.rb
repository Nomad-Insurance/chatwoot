class Accounting::BrandingUpdater
  BRANDING_FIELDS = {
    name: :branding_name=,
    installation_name: :branding_installation_name=,
    brand_url: :branding_brand_url=,
    widget_brand_url: :branding_widget_brand_url=,
    terms_url: :branding_terms_url=,
    privacy_url: :branding_privacy_url=,
    primary_color: :branding_primary_color=
  }.freeze

  def initialize(account:, params:)
    @account = account
    @params = params || {}
  end

  def update!
    BRANDING_FIELDS.each do |param_key, writer|
      next unless @params.key?(param_key)

      value = @params[param_key]
      @account.public_send(writer, value.presence)
    end

    @account.save!
  end
end
