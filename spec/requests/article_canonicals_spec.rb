require 'rails_helper'

RSpec.describe 'Article website canonicals', type: :request do
  let!(:account) { create(:account) }
  let!(:portal) { create(:portal, account: account, slug: 'expat-insurance-helpdesk') }
  let!(:domain) { AccountDomain.create!(account: account, host: 'support.example.test') }
  let!(:article) { create(:article, portal: portal, account: account, slug: 'checklist-for-claims', locale: 'en') }

  around do |example|
    with_modified_env FRONTEND_URL: 'https://shared.example.test', HELPCENTER_URL: '' do
      example.run
    end
  end

  before { host! domain.host }

  def article_path
    "/hc/#{portal.slug}/articles/#{article.slug}"
  end

  def canonicals
    Nokogiri::HTML(response.body).css('link[rel="canonical"]').map { |tag| tag['href'] }
  end

  %w[classic documentation].each do |layout|
    it "uses the website canonical in #{layout}, without query parameters" do
      portal.update!(config: { layout: layout })
      get article_path, params: { theme: 'dark', show_plain_layout: 'false' }
      expect(response).to have_http_status(:ok)
      expect(canonicals).to eq(['https://www.expatinsurance.com/articles/support/checklist-for-claims'])
    end
  end

  it 'BLOCKING: keeps an included slug on another tenant self-canonical' do
    other_account = create(:account)
    other_portal = create(:portal, account: other_account)
    other_domain = AccountDomain.create!(account: other_account, host: 'other.example.test')
    article.update!(portal: other_portal, account: other_account)
    host! other_domain.host
    path = "/hc/#{other_portal.slug}/articles/#{article.slug}"
    get path
    expect(response).to have_http_status(:ok)
    expect(canonicals).to eq(["https://#{other_domain.host}#{path}"])
  end

  it 'keeps another portal on the same account self-canonical' do
    other_portal = create(:portal, account: account)
    article.update!(portal: other_portal)
    path = "/hc/#{other_portal.slug}/articles/#{article.slug}"
    get path
    expect(response).to have_http_status(:ok)
    expect(canonicals).to eq(["https://#{domain.host}#{path}"])
  end

  %w[how-and-when-to-precertify-with-morgan-white new-article-not-reviewed].each do |slug|
    it "keeps #{slug} self-canonical" do
      article.update!(slug: slug)
      get article_path
      expect(response).to have_http_status(:ok)
      expect(canonicals).to eq(["https://#{domain.host}#{article_path}"])
    end
  end

  it 'keeps another locale self-canonical' do
    portal.update!(config: { allowed_locales: %w[en es] })
    article.update!(locale: 'es')
    get article_path
    expect(response).to have_http_status(:ok)
    expect(canonicals).to eq(["https://#{domain.host}#{article_path}"])
  end

  it 'keeps portal and category canonicals unchanged' do
    category = create(:category, portal: portal, locale: 'en')
    ["/hc/#{portal.slug}/en", "/hc/#{portal.slug}/en/categories/#{category.slug}"].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(canonicals).to eq(["https://#{domain.host}#{path}"])
    end
  end

  it 'BLOCKING: preserves the cross-host redirect to the authorized portal, not the website' do
    other_account = create(:account)
    AccountDomain.create!(account: other_account, host: 'other.example.test')
    host! 'other.example.test'
    get article_path
    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to eq("https://#{domain.host}#{article_path}")
  end

  it 'keeps preview responses without canonicals and non-indexable' do
    article.update!(status: :draft)
    purpose = "help_center_preview:#{portal.id}:#{domain.host}"
    token = article.signed_id(purpose: purpose, expires_in: 15.minutes)
    get "#{article_path}/preview", params: { preview_token: token }
    expect(response).to have_http_status(:ok)
    expect(canonicals).to be_empty
    expect(response.headers['X-Robots-Tag']).to include('noindex')
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  %w[draft archived].each do |status|
    it "keeps #{status} articles unavailable" do
      article.update!(status: status)
      get article_path
      expect(response).to have_http_status(:not_found)
      expect(canonicals).to be_empty
    end
  end

  it 'BLOCKING: keeps the sitemap on the portal origin under D191' do
    get "/hc/#{portal.slug}/sitemap.xml"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("https://#{domain.host}#{article_path}")
    expect(response.body).not_to include('https://www.expatinsurance.com/articles/support/')
  end
end
