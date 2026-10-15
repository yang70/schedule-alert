require "test_helper"

class CheckConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "competing dispatchers acquire only one committed lease" do
    user = create_user(email: "concurrency@example.com")
    monitored = create_url(user: user)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          record = MonitoredUrl.find(monitored.id)
          ready << true
          start.pop
          results << record.request_check!
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:value)
    assert_equal [ :busy, :queued ], 2.times.map { results.pop }.sort
    assert monitored.reload.check_token.present?
  ensure
    user&.destroy!
  end
end
