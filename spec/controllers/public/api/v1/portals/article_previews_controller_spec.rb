require 'rails_helper'

RSpec.describe 'Help Center article previews', type: :request do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let!(:portal) { create(:portal, account: account) }
  let!(:article) { create(:article, account: account, portal: portal, status: :draft) }
  let!(:domain) { AccountDomain.create!(account: account, host: 'portal.expatinsurance.com') }
  let!(:other_domain) { AccountDomain.create!(account: other_account, host: 'portal.nomadinsurance.com') }
  let(:api_path) { "/api/v1/accounts/#{account.id}/portals/#{portal.slug}/articles/#{article.id}/preview" }
  let(:preview_path) { "/hc/#{portal.slug}/articles/#{article.slug}/preview" }

  around do |example|
    with_modified_env FRONTEND_URL: "https://#{other_domain.host}", HELPCENTER_URL: '' do
      example.run
    end
  end

  before { host! domain.host }

  def issue_preview
    post api_path, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    response.parsed_body
  end

  it 'requires authentication' do
    post api_path
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects ordinary agents' do
    agent = create(:user, account: account, role: :agent)
    post api_path, headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects administrators from another account' do
    outsider = create(:user, account: other_account, role: :administrator)
    post api_path, headers: outsider.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end

  it 'scopes the portal and article to the authenticated account' do
    other_portal = create(:portal, account: other_account)
    post api_path.sub(portal.slug, other_portal.slug), headers: admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)

    other_article = create(:article, portal: other_portal, account: other_account)
    post api_path.sub("/#{article.id}/preview", "/#{other_article.id}/preview"), headers: admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)
  end

  %w[draft archived].each do |status|
    it "renders a signed #{status} preview only on the dedicated route" do
      article.update!(status: status)
      data = issue_preview
      expect(data['base_url']).to eq("http://#{domain.host}")
      expect(response.headers['Cache-Control']).to include('no-store')
      get preview_path, params: { preview_token: data['preview_token'] }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(article.title)
      expect(response.headers).to include(
        'Cache-Control' => 'no-store',
        'X-Robots-Tag' => 'noindex, nofollow',
        'Referrer-Policy' => 'no-referrer'
      )
      expect(response.body).not_to include('rel="canonical"', 'viewTracked')

      get preview_path.delete_suffix('/preview'), params: { preview_token: data['preview_token'] }
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'renders the documentation layout for a signed preview' do
    portal.update!(config: { layout: 'documentation' })
    data = issue_preview
    get preview_path, params: { preview_token: data['preview_token'] }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(article.title, 'cw-article-content')
    expect(response.body).not_to include('rel="canonical"', 'viewTracked')
  end

  it 'does not expose published previews on another tenant host either' do
    article.update!(status: :published)
    data = issue_preview
    host! other_domain.host
    get preview_path, params: { preview_token: data['preview_token'] }
    expect(response).to have_http_status(:not_found)
    expect(response.headers['Location']).to be_nil
  end

  it 'rejects absent, forged and expired tokens' do
    token = issue_preview['preview_token']
    [nil, 'forged', "#{token}tampered"].each do |invalid_token|
      get preview_path, params: { preview_token: invalid_token }
      expect(response).to have_http_status(:not_found)
    end
    travel 16.minutes do
      get preview_path, params: { preview_token: token }
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'binds tokens to the article, portal and hostname' do
    token = issue_preview['preview_token']
    other_article = create(:article, account: account, portal: portal, status: :draft)
    get preview_path.sub(article.slug, other_article.slug), params: { preview_token: token }
    expect(response).to have_http_status(:not_found)

    other_portal = create(:portal, account: account)
    get preview_path.sub(portal.slug, other_portal.slug), params: { preview_token: token }
    expect(response).to have_http_status(:not_found)

    AccountDomain.create!(account: account, host: 'alias.expatinsurance.com')
    host! 'alias.expatinsurance.com'
    get preview_path, params: { preview_token: token }
    expect(response).to have_http_status(:not_found)

    host! other_domain.host
    get preview_path, params: { preview_token: token }
    expect(response).to have_http_status(:not_found)
    expect(response.headers['Location']).to be_nil
  end

  it 'prefers an explicit portal custom domain over the current branded host' do
    portal.update!(custom_domain: 'help.expatinsurance.com')
    data = issue_preview
    expect(data['base_url']).to eq('https://help.expatinsurance.com')
    host! portal.custom_domain
    get preview_path, params: { preview_token: data['preview_token'] }
    expect(response).to have_http_status(:ok)
  end

  it 'uses only an explicitly configured neutral shared host as a fallback' do
    host! other_domain.host
    with_modified_env HELPCENTER_URL: 'https://help.example.com' do
      data = issue_preview
      expect(data['base_url']).to eq('https://help.example.com')
      host! 'help.example.com'
      get preview_path, params: { preview_token: data['preview_token'] }
      expect(response).to have_http_status(:ok)
    end
  end

  it 'does not fall back to FRONTEND_URL or another tenant configured as HELPCENTER_URL' do
    host! other_domain.host
    post api_path, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:unprocessable_entity)

    with_modified_env HELPCENTER_URL: "https://#{other_domain.host}" do
      post api_path, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it 'rejects previews after the portal is archived' do
    data = issue_preview
    portal.update!(archived: true)
    get preview_path, params: { preview_token: data['preview_token'] }
    expect(response).to have_http_status(:not_found)
    post api_path, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)
  end
end
