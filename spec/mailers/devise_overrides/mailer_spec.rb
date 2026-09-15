require 'rails_helper'

RSpec.describe DeviseOverrides::Mailer do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  it 'preserves an explicit confirmation reply-to' do
    mail = Devise.mailer.confirmation_instructions(user, nil, reply_to: user.email)
    expect(mail.reply_to).to eq([user.email])
  end

  it 'does not apply the confirmation default when From is overridden' do
    mail = Devise.mailer.confirmation_instructions(user, nil, from: user.email)
    expect(mail.from).to eq([user.email])
    expect(mail.reply_to).to eq([Mail::Address.new(Devise.mailer_sender).address])
  end

  it 'preserves the password reset reply-to fallback' do
    mail = Devise.mailer.reset_password_instructions(user, nil)
    expect(mail.reply_to).to eq([Mail::Address.new(Devise.mailer_sender).address])
  end

  it 'leaves transcript Reply-To absent while retaining its own From' do
    mailer = ConversationReplyMailer.new
    allow(ConversationReplyMailer).to receive(:new).and_return(mailer)
    allow(mailer).to receive(:smtp_config_set_or_development?).and_return(true)
    account.update!(support_email: user.email)
    conversation = create(:conversation, account: account, assignee: user)
    create(:message, account: account, conversation: conversation)
    mail = ConversationReplyMailer.conversation_transcript(conversation, user.email)
    expect(mail.from).to eq([Mail::Address.new(account.support_email).address])
    expect(mail.reply_to).to be_nil
  end
end
