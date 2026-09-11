class Public::Api::V1::Portals::ArticlePreviewsController < Public::Api::V1::Portals::ArticlesController
  def show
    @preview = true
    response.headers['Cache-Control'] = 'no-store'
    response.headers['X-Robots-Tag'] = 'noindex, nofollow'
    response.headers['Referrer-Policy'] = 'no-referrer'
    super
    render 'public/api/v1/portals/articles/show'
  end

  private

  def published_page?
    false
  end

  def load_public_article
    purpose = "help_center_preview:#{@portal.id}:#{HostNormalizer.normalize(request.host)}"
    article = Article.find_signed(params[:preview_token], purpose: purpose)
    raise ActiveRecord::RecordNotFound unless article && article.portal_id == @portal.id && article.slug == params[:article_slug]

    @article = article
  end
end
