module DeviseConfirmationReplyTo
  def confirmation_instructions(record, token, opts = {})
    opts = { reply_to: ApplicationMailer.default[:from] }.merge(opts) unless opts.key?(:from)
    super(record, token, opts)
  end
end

Rails.application.config.to_prepare do
  Devise::Mailer.prepend(DeviseConfirmationReplyTo) unless Devise::Mailer < DeviseConfirmationReplyTo
end
