class AccountForHost
  class << self
    def call(raw_host)
      host = HostNormalizer.normalize(raw_host)
      return if host.blank?

      account = AccountDomain.includes(:account).find_by(host: host)&.account
      return account if account

      Portal.find_by(custom_domain: host)&.account
    end
  end
end
