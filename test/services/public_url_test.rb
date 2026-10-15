require "test_helper"

class PublicUrlTest < ActiveSupport::TestCase
  test "DNS rebinding and mixed public private responses are rejected" do
    Resolv.stub(:getaddresses, [ "8.8.8.8", "127.0.0.1" ]) do
      assert_raises(PublicUrl::UnsafeUrl) { PublicUrl.resolve!("https://example.com") }
    end
    Resolv.stub(:getaddresses, [ "169.254.169.254" ]) do
      assert_raises(PublicUrl::UnsafeUrl) { PublicUrl.resolve!("https://example.com") }
    end
  end

  test "public IPv4 and IPv6 addresses are allowed and reserved networks rejected" do
    assert PublicUrl.public_address?("8.8.8.8")
    assert PublicUrl.public_address?("2606:4700::1111")
    %w[0.0.0.0 100.64.1.2 192.168.1.1 198.18.1.2 224.0.0.1 ::1 fc00::1 fe80::1 2001:db8::1 2002:7f00:1::].each do |ip|
      assert_not PublicUrl.public_address?(ip), ip
    end
  end

  test "proxy blocks private CONNECT requests before opening an upstream socket" do
    proxy = SafeFetchProxy.new.start
    socket = TCPSocket.new("127.0.0.1", URI.parse(proxy.url).port)
    socket.write("CONNECT 169.254.169.254:443 HTTP/1.1\r\nHost: 169.254.169.254\r\n\r\n")
    assert_match "502", socket.gets
  ensure
    socket&.close
    proxy&.stop
  end

  test "document redirects into private networks are rejected" do
    Resolv.stub(:getaddresses, [ "8.8.8.8" ]) do
      stub_request(:get, "https://example.com/schedule.pdf").to_return(status: 302, headers: { "Location" => "http://169.254.169.254/latest/meta-data/" })
      assert_raises(PublicUrl::UnsafeUrl) { SafeHttpClient.new.get("https://example.com/schedule.pdf") }
      assert_requested :get, "https://example.com/schedule.pdf", times: 1
    end
  end
end
