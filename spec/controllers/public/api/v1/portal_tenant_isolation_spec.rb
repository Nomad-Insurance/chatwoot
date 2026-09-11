require 'rails_helper'

RSpec.describe 'Help Center tenant isolation', type: :request do
  let!(:nomad) { create(:account) }
  let!(:expat) { create(:account) }
  let!(:nomad_domain) { AccountDomain.create!(account: nomad, host: 'portal.nomadinsurance.com') }
  let!(:expat_domain) { AccountDomain.create!(account: expat, host: 'portal.expatinsurance.com') }
  let!(:nomad_portal) { create(:portal, account: nomad) }
  let!(:portal) { create(:portal, account: expat, slug: 'expat-insurance-helpdesk') }
  let!(:category) { create(:category, portal: portal, locale: 'en') }
  let!(:article) { create(:article, account: expat, portal: portal, category: category) }

  around do |example|
    with_modified_env FRONTEND_URL: 'https://portal.nomadinsurance.com', HELPCENTER_URL: '' do
      example.run
    end
  end

  # HTML pages can redirect only when the target tenant has one canonical host.
  routes = {
    home: ['', :found],
    locale: ['/en', :ok],
    category: ['/en/categories/%CATEGORY%', :ok],
    categories: ['/en/categories.json', :ok],
    articles: ['/en/articles.json', :ok],
    category_articles: ['/en/categories/%CATEGORY%/articles.json', :ok],
    article: ['/articles/%ARTICLE%', :ok],
    search: ['/en/search?query=MyText', :ok],
    markdown: ['/articles/%ARTICLE%.md', :ok],
    sitemap: ['/sitemap.xml', :ok],
    pixel: ['/articles/%ARTICLE%.png', :ok]
  }.freeze

  def public_path(suffix)
    "/hc/#{portal.slug}#{suffix}".gsub('%CATEGORY%', category.slug).gsub('%ARTICLE%', article.slug)
  end

  routes.each do |name, (suffix, status)|
    it "serves #{name} on its account hostname" do
      host! expat_domain.host
      get public_path(suffix)
      expect(response).to have_http_status(status)
    end

    it "rejects #{name} on the other tenant when the canonical host is ambiguous" do
      AccountDomain.create!(account: expat, host: 'another.expatinsurance.com')
      host! nomad_domain.host
      get public_path(suffix)
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(article.title, portal.name)
    end

    it "never renders #{name} on the other tenant's FRONTEND_URL" do
      host! nomad_domain.host
      get public_path(suffix)
      expected = %i[home locale category article].include?(name) ? :moved_permanently : :not_found
      expect(response).to have_http_status(expected)
      expect(response.body).not_to include(article.content)
      expect(response.location).to start_with("https://#{expat_domain.host}/hc/#{portal.slug}") if expected == :moved_permanently
    end

    it "rejects #{name} on another portal's custom domain without replacing the portal" do
      AccountDomain.create!(account: expat, host: 'another.expatinsurance.com')
      other_portal = create(:portal, account: expat, custom_domain: 'other.expatinsurance.com')
      host! other_portal.custom_domain
      get public_path(suffix)
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(other_portal.name, article.content)
    end

    it "serves #{name} on the portal custom domain" do
      portal.update!(custom_domain: 'help.expatinsurance.com')
      host! portal.custom_domain
      get public_path(suffix)
      expect(response).to have_http_status(status)
    end
  end

  it 'does not replace the requested portal with another portal on the same account' do
    other_portal = create(:portal, account: expat, custom_domain: 'other.expatinsurance.com')
    host! other_portal.custom_domain
    get "/hc/#{portal.slug}/en"
    expect(response).to redirect_to("https://#{expat_domain.host}/hc/#{portal.slug}/en")
    expect(response.body).not_to include(other_portal.name)
  end

  it 'rejects archived portals, including on their custom domain' do
    portal.update!(archived: true, custom_domain: 'help.expatinsurance.com')
    host! portal.custom_domain
    get "/hc/#{portal.slug}/en"
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects an unknown portal without substituting the host portal' do
    portal.update!(custom_domain: 'help.expatinsurance.com')
    host! portal.custom_domain
    get '/hc/missing/en'
    expect(response).to have_http_status(:not_found)
  end

  it 'scopes article resolution to the requested portal' do
    host! nomad_domain.host
    get "/hc/#{nomad_portal.slug}/articles/#{article.slug}"
    expect(response).to have_http_status(:not_found)
  end

  it 'honors AccountDomain ownership even when a conflicting portal custom domain exists' do
    portal.update!(custom_domain: nomad_domain.host)
    expect(AccountForHost.call(nomad_domain.host)).to eq(nomad)
    expect(DomainHelper.chatwoot_domain?(nomad_domain.host)).to be(false)
    host! nomad_domain.host
    get public_path('/articles/%ARTICLE%.md')
    expect(response).to have_http_status(:not_found)
  end

  it 'allows an explicitly neutral shared Help Center host' do
    with_modified_env HELPCENTER_URL: 'https://help.example.com' do
      host! 'help.example.com'
      get public_path('/articles/%ARTICLE%')
      expect(response).to have_http_status(:ok)
    end
  end

  it 'does not treat a mapped HELPCENTER_URL as a shared hostname' do
    with_modified_env HELPCENTER_URL: "https://#{nomad_domain.host}" do
      host! nomad_domain.host
      get public_path('/articles/%ARTICLE%.md')
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'preserves an unowned FRONTEND_URL for existing shared installations' do
    with_modified_env FRONTEND_URL: 'https://shared.example.com' do
      host! 'shared.example.com'
      get public_path('/articles/%ARTICLE%')
      expect(response).to have_http_status(:ok)
    end
  end

  extensions = ['', '.md', '.png']
  hosts = %w[portal.nomadinsurance.com portal.expatinsurance.com]
  %w[draft archived].each do |status|
    extensions.each do |extension|
      hosts.each do |host|
        it "returns 404 for a #{status} article#{extension} on #{host}" do
          article.update!(status: status)
          host! host
          get "/hc/#{portal.slug}/articles/#{article.slug}#{extension}"
          expect(response).to have_http_status(:not_found)
          expect(response.headers['Location']).to be_nil
          expect(response.body).not_to include(article.content)
          expect(article.reload.views).to eq(0)
        end
      end
    end
  end

  page_suffixes = %w[/en /en/categories/%CATEGORY% /articles/%ARTICLE%]
  %w[classic documentation].each do |layout|
    page_suffixes.each do |suffix|
      it "emits a clean canonical URL for #{layout} #{suffix}" do
        portal.update!(config: { layout: layout })
        host! expat_domain.host
        get public_path(suffix), params: { theme: 'dark', show_plain_layout: 'false' }
        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        expect(document.at_css('link[rel="canonical"]')['href']).to eq("https://#{expat_domain.host}#{public_path(suffix)}")
      end
    end
  end

  it 'prefers the custom domain in canonical tags and sitemap URLs' do
    portal.update!(custom_domain: 'help.expatinsurance.com')
    host! expat_domain.host
    get public_path('/articles/%ARTICLE%')
    expect(Nokogiri::HTML(response.body).at_css('link[rel="canonical"]')['href'])
      .to eq("https://help.expatinsurance.com#{public_path('/articles/%ARTICLE%')}")

    get public_path('/sitemap.xml')
    expect(response.body).to include("https://help.expatinsurance.com#{public_path('/articles/%ARTICLE%')}")
    expect(response.body).not_to include(nomad_domain.host)
  end

  it 'keeps drafts, archives and other tenants out of indexes, search and sitemap' do
    hidden = %w[draft archived].map { |status| create(:article, account: expat, portal: portal, category: category, status: status) }
    hidden << create(:article, account: nomad, portal: nomad_portal)
    host! expat_domain.host
    %w[/en/articles.json /en/search?query=MyText /sitemap.xml].each do |suffix|
      get public_path(suffix)
      expect(response).to have_http_status(:ok)
      hidden.each { |item| expect(response.body).not_to include(item.title, item.slug) }
    end
    get public_path('/en/articles.json'), params: { status: 'draft' }
    expect(response.parsed_body['payload']).to be_empty
  end

  it 'does not redirect nonexistent content' do
    host! nomad_domain.host
    get "/hc/#{portal.slug}/articles/missing"
    expect(response).to have_http_status(:not_found)
    get "/hc/#{portal.slug}/en/categories/missing"
    expect(response).to have_http_status(:not_found)
  end
end
