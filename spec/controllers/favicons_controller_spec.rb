require 'rails_helper'

RSpec.describe FaviconsController, type: :request do
  let(:account) { create(:account) }
  let(:portal) { create(:portal, account: account, custom_domain: 'help.example.com') }

  describe 'GET /favicons/:size.png' do
    it 'redirects to the uploaded thumbnail without processing a variant' do
      portal
      account.logo_thumbnail.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'avatar.png',
        content_type: 'image/png'
      )

      get '/favicons/96.png', headers: { 'HTTP_HOST' => portal.custom_domain }

      expect(response).to redirect_to(%r{/rails/active_storage/blobs/redirect/})
      expect(response.location).not_to include('/representations/')
    end
  end
end
