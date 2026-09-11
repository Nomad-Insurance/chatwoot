# TODO: we should switch to ActionController::API for the base classes
# One of the specs is failing when I tried doing that, lets revisit in future
class PublicController < ActionController::Base
  include RequestExceptionHandler
  skip_before_action :verify_authenticity_token

  private

  def ensure_portal_feature_enabled
    return unless ChatwootApp.chatwoot_cloud?
    return if @portal.account.feature_enabled?('help_center')

    render 'public/api/v1/portals/not_active', status: :payment_required
  end
end
