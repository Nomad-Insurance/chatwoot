class DeviseOverrides::Mailer < Devise::Mailer
  def confirmation_instructions(record, token, opts = {})
    opts = { reply_to: ApplicationMailer.default[:from] }.merge(opts) unless opts.key?(:from)
    super(record, token, opts)
  end
end
