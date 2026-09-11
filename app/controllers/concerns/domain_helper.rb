module DomainHelper
  def self.chatwoot_domain?(domain = request.host)
    domain = HostNormalizer.normalize(domain)
    return false if AccountForHost.call(domain)

    [URI.parse(ENV.fetch('FRONTEND_URL', '')).host, URI.parse(ENV.fetch('HELPCENTER_URL', '')).host].include?(domain)
  end
end
