require "net/http"
require "timeout"

class SafeHttpClient
  MAX_BYTES = 5.megabytes
  Response = Data.define(:body, :content_type, :url)

  def get(url, redirects: 3)
    Timeout.timeout(30) { fetch(url, redirects) }
  rescue Timeout::Error, IOError, SystemCallError, OpenSSL::SSL::SSLError => error
    raise MonitoringError, "Unable to download the document (#{error.class.name})"
  end

  private

  def fetch(url, redirects)
    uri, address = PublicUrl.resolve!(url)
    http = Net::HTTP.new(uri.hostname, uri.port, nil)
    http.ipaddr = address
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10
    http.max_retries = 0
    result = nil
    redirect = nil
    http.request(Net::HTTP::Get.new(uri.request_uri, "User-Agent" => "TourneyPing/1.0", "Accept-Encoding" => "identity")) do |response|
      if response.is_a?(Net::HTTPRedirection)
        raise MonitoringError, "Too many document redirects" if redirects.zero? || response["location"].blank?
        redirect = URI.join(uri.to_s, response["location"]).to_s
        redirect_bytes = 0
        response.read_body do |chunk|
          redirect_bytes += chunk.bytesize
          raise MonitoringError, "Redirect response exceeds the size limit" if redirect_bytes > 16.kilobytes
        end
      else
        raise MonitoringError, "Document returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
        raise MonitoringError, "Document exceeds the download limit" if response["content-length"].to_i > MAX_BYTES
        body = +"".b
        response.read_body do |chunk|
          body << chunk
          raise MonitoringError, "Document exceeds the download limit" if body.bytesize > MAX_BYTES
        end
        result = Response.new(body: body, content_type: response["content-type"].to_s.split(";").first.to_s.downcase, url: uri.to_s)
      end
    end
    redirect ? fetch(redirect, redirects - 1) : result
  rescue URI::InvalidURIError
    raise MonitoringError, "Invalid document redirect"
  end
end
