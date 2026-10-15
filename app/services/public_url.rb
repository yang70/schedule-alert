require "ipaddr"
require "resolv"

class PublicUrl
  class UnsafeUrl < MonitoringError; end

  BLOCKED_IPV4 = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4].map { |range| IPAddr.new(range) }.freeze
  IPV6_GLOBAL = IPAddr.new("2000::/3")
  BLOCKED_IPV6 = %w[2001::/23 2001:db8::/32 2002::/16 3fff::/20].map { |range| IPAddr.new(range) }.freeze

  def self.parse!(url)
    raise UnsafeUrl, "Invalid URL" unless url.is_a?(String) && url.length <= 2048 && !url.match?(/[\s\x00-\x1f\x7f\\]/)
    uri = URI.parse(url)
    host = uri.hostname&.downcase
    raise UnsafeUrl, "Invalid URL" unless %w[http https].include?(uri.scheme) && host.present? && uri.userinfo.nil? && [ 80, 443 ].include?(uri.port)
    raise UnsafeUrl, "Private hostname" if host == "localhost" || host.end_with?(".localhost", ".local", ".internal", ".test", ".invalid") || !host.include?(".") && !host.include?(":")
    if ip_literal?(host)
      raise UnsafeUrl, "Private address" unless public_address?(host)
    else
      raise UnsafeUrl, "Invalid hostname" unless host.match?(/\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/) && !host.include?("..")
      # Reject alternate numeric encodings that browsers interpret as IPv4.
      raise UnsafeUrl, "Ambiguous numeric address" if host.split(".").all? { |part| part.match?(/\A(?:\d+|0x[0-9a-f]+)\z/i) }
    end
    uri
  rescue URI::InvalidURIError, IPAddr::InvalidAddressError
    raise UnsafeUrl, "Invalid URL"
  end

  def self.resolve!(url)
    uri = parse!(url)
    addresses = if ip_literal?(uri.hostname)
      [ uri.hostname ]
    else
      Resolv.getaddresses(uri.hostname)
    end
    raise UnsafeUrl, "Hostname does not resolve to public addresses" if addresses.empty? || addresses.any? { |address| !public_address?(address) }
    [ uri, addresses.first ]
  rescue Resolv::ResolvError
    raise UnsafeUrl, "Unable to resolve hostname"
  end

  def self.public_address?(address)
    ip = IPAddr.new(address)
    ip = ip.native if ip.ipv4_mapped?
    if ip.ipv4?
      BLOCKED_IPV4.none? { |range| range.include?(ip) }
    else
      IPV6_GLOBAL.include?(ip) && BLOCKED_IPV6.none? { |range| range.include?(ip) }
    end
  rescue IPAddr::InvalidAddressError
    false
  end

  def self.ip_literal?(host)
    IPAddr.new(host)
    true
  rescue IPAddr::InvalidAddressError
    false
  end
end
