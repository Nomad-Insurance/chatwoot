require 'json'

# Shared by public routes and authenticated preview issuance.
class PortalHostPolicy
  ARTICLE_CANONICALS = JSON.parse(File.read(File.expand_path('../../config/help_center_article_canonicals.json', __dir__))).freeze

  def initialize(portal)
    @portal = portal
  end

  def allowed?(host)
    host = HostNormalizer.normalize(host)
    owner = AccountForHost.call(host)
    domain_portal = Portal.find_by(custom_domain: host)

    return false if owner && owner.id != @portal.account_id
    return false if domain_portal && domain_portal.id != @portal.id

    owner.present? || domain_portal.present? || DomainHelper.chatwoot_domain?(host)
  end

  def canonical_origin
    return custom_origin if custom_origin

    hosts = AccountDomain.where(account_id: @portal.account_id).pluck(:host).select { |host| allowed?(host) }
    "https://#{hosts.first}" if hosts.one?
  end

  def preview_origin(request)
    return custom_origin if custom_origin
    return request.base_url if AccountForHost.call(request.host)&.id == @portal.account_id && allowed?(request.host)

    self.class.shared_origin
  end

  def public_origin(request)
    canonical_origin || self.class.shared_origin || request.base_url
  end

  # Used only by the canonical-tag helper; never by redirects, sitemaps or previews.
  def article_canonical_url(article)
    config = ARTICLE_CANONICALS
    return unless @portal.slug == config.fetch('portal_slug')
    return unless article&.published? && article.locale == config.fetch('locale')
    return unless article_belongs_to_portal?(article)
    return unless config.fetch('included_slugs').include?(article.slug)

    "#{config.fetch('website_origin')}#{config.fetch('website_prefix')}#{article.slug}"
  end

  def self.shared_origin
    url = ENV['HELPCENTER_URL'].presence
    return unless url

    uri = URI.parse(url)
    return unless %w[http https].include?(uri.scheme) && uri.host.present?
    return if AccountForHost.call(uri.host)

    url.chomp('/')
  end

  private

  def article_belongs_to_portal?(article)
    article.portal_id == @portal.id && article.account_id == @portal.account_id
  end

  def custom_origin
    host = @portal.custom_domain.presence
    "https://#{host}" if host && allowed?(host)
  end
end
