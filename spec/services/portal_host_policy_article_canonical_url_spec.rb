require 'rails_helper'

RSpec.describe PortalHostPolicy, '#article_canonical_url' do
  let(:portal) { build_stubbed(:portal, slug: 'expat-insurance-helpdesk') }
  let(:article) { build_stubbed(:article, portal: portal, account: portal.account, locale: 'en', slug: 'checklist-for-claims') }

  def resolve
    described_class.new(portal).article_canonical_url(article)
  end

  it 'maps every reviewed slug, and only the reviewed inventory' do
    config = described_class::ARTICLE_CANONICALS
    expect(config.fetch('included_slugs').size).to eq(74)
    expect(config.fetch('excluded_slugs').size).to eq(18)
    expect((config.fetch('included_slugs') + config.fetch('excluded_slugs')).uniq.size).to eq(92)
    config.fetch('included_slugs').each do |slug|
      article.slug = slug
      expect(resolve).to eq("https://www.expatinsurance.com/articles/support/#{slug}")
    end
  end

  it 'keeps all 18 exclusions and unknown slugs on the existing canonical path' do
    (described_class::ARTICLE_CANONICALS.fetch('excluded_slugs') + ['unreviewed-new-article']).each do |slug|
      article.slug = slug
      expect(resolve).to be_nil
    end
  end

  it 'BLOCKING: does not map a matching slug in another portal' do
    portal.slug = 'another-portal'
    expect(resolve).to be_nil
  end

  it 'rejects a mismatched article portal even when the supplied portal slug is approved' do
    article.portal_id = portal.id + 1
    expect(resolve).to be_nil
  end

  it 'rejects a mismatched article account' do
    article.account_id = portal.account_id + 1
    expect(resolve).to be_nil
  end

  it 'does not map another locale' do
    article.locale = 'es'
    expect(resolve).to be_nil
  end

  %w[draft archived].each do |status|
    it "does not map #{status} articles" do
      article.status = status
      expect(resolve).to be_nil
    end
  end

  it 'does not map a page without an article' do
    expect(described_class.new(portal).article_canonical_url(nil)).to be_nil
  end
end
