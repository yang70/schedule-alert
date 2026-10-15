require "tempfile"
require "timeout"
require "rbconfig"

class PdfTextExtractor
  def extract(bytes)
    raise MonitoringError, "The linked document is not a PDF" unless bytes.start_with?("%PDF-")
    Tempfile.create([ "schedule", ".pdf" ]) do |input|
      Tempfile.create("schedule-text") do |output|
        input.binmode
        input.write(bytes)
        input.flush
        env = { "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s }
        %w[BUNDLE_PATH BUNDLE_WITHOUT GEM_HOME GEM_PATH].each { |key| env[key] = ENV[key] if ENV[key] }
        limits = { rlimit_cpu: 10, rlimit_fsize: 256.kilobytes }
        limits[:rlimit_as] = 256.megabytes if RUBY_PLATFORM.include?("linux")
        pid = Process.spawn(env, RbConfig.ruby, Rails.root.join("bin/extract-pdf").to_s, input.path,
          out: output, err: File::NULL, unsetenv_others: true, **limits)
        begin
          Timeout.timeout(15) { Process.waitpid(pid) }
          raise MonitoringError, "Unable to read the PDF schedule" unless $?.success?
          output.rewind
          text = output.read.force_encoding(Encoding::UTF_8).scrub
          raise MonitoringError, "The PDF has no readable text; a text-based schedule is required" if text.strip.empty?
          text
        rescue Timeout::Error
          Process.kill("KILL", pid) rescue nil
          Process.waitpid(pid) rescue nil
          raise MonitoringError, "PDF parsing exceeded the time limit"
        end
      end
    end
  end
end
