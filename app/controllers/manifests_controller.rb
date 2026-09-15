class ManifestsController < ApplicationController
  def show
    account = AccountForHost.call(request.host)
    branding = BrandingConfig.new(account: account)

    render json: manifest_payload(branding)
  end

  private

  def manifest_payload(branding)
    color = branding.primary_color || '#1f93ff'

    {
      name: branding.installation_name,
      short_name: branding.brand_name || branding.installation_name,
      icons: manifest_icons,
      start_url: '/',
      display: 'standalone',
      background_color: color,
      theme_color: color
    }
  end

  def manifest_icons
    [
      manifest_icon(36, '0.75'),
      manifest_icon(48, '1.0'),
      manifest_icon(72, '1.5'),
      manifest_icon(96, '2.0'),
      manifest_icon(144, '3.0'),
      manifest_icon(192, '4.0')
    ]
  end

  def manifest_icon(size, density)
    {
      src: "/favicons/#{size}.png",
      sizes: "#{size}x#{size}",
      type: 'image/png',
      density: density
    }
  end
end
