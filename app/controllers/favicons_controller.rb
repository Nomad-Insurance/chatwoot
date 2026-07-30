class FaviconsController < ActionController::Base
  SIZES = %w[16 32 36 48 72 96 144 192].freeze

  def show
    size = params[:size]
    return head :not_found unless SIZES.include?(size)

    account = AccountForHost.call(request.host)
    if account&.logo_thumbnail&.attached?
      redirect_to rails_blob_path(account.logo_thumbnail, only_path: true)
    else
      send_global_favicon(size)
    end
  end

  private

  def send_global_favicon(size)
    path = Rails.root.join("public/favicon-#{size}x#{size}.png")
    path = Rails.public_path.join('favicon-512x512.png') unless File.exist?(path)

    if File.exist?(path)
      send_file path, type: 'image/png', disposition: 'inline'
    else
      head :not_found
    end
  end
end
