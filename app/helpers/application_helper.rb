module ApplicationHelper
  def safe_external_url(value)
    PublicUrl.parse!(value).to_s
  rescue PublicUrl::UnsafeUrl
    "#"
  end
end
