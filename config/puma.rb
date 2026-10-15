threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", "3"))
threads threads_count, threads_count
bind ENV.fetch("PUMA_BIND", ENV["RAILS_ENV"] == "production" ? "tcp://127.0.0.1:3000" : "tcp://0.0.0.0:3000")
plugin :tmp_restart
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
