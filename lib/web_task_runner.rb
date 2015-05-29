$stdout.sync = true

require 'sinatra'
require 'dotenv'
Dotenv.load

require "web_task_runner/version"
require "web_task_runner/redis_module"
require "web_task_runner/task_worker"

class WebTaskRunner < Sinatra::Application
  @@jobs = []

  def self.jobs
    @@jobs
  end

  # GET /?key=<api_key> - retrieve current state of the crawler
  get '/' do
    # Authorize the request
    error 401, JSON.pretty_generate(error: 'Unauthorized') and \
      return if ENV['API_KEY'] != params[:key]

    return JSON.pretty_generate(current_info)
  end

  # GET /start?key=<api_key> - start the crawler if idle
  get '/start' do
    # Authorize the request
    error 401, JSON.pretty_generate(error: 'Unauthorized') and \
      return if ENV['API_KEY'] != params[:key]

    start_task_if_idle

    return 'start'
  end

  # GET /kill?key=<api_key> - kill the working job
  get '/kill' do
    # Authorize the request
    error 401, JSON.pretty_generate(error: 'Unauthorized') and \
      return if ENV['API_KEY'] != params[:key]

    kill_task

    return 'kill'
  end

  # Report that a worker has done working, call this in each worker after
  # the work has done
  def self.work_ended(all: false)
    if all
      WebTaskRunner::RedisModule.redis.set('task:working_jobs', 0)
    else
      # decrease the working workers count
      WebTaskRunner::RedisModule.redis.decr('task:working_jobs')
    end

    # set the state to idle if all the works has been done
    if WebTaskRunner::RedisModule.redis.get('task:working_jobs').to_i < 1
      WebTaskRunner::RedisModule.redis.set('task:state', 'idle')
      WebTaskRunner::RedisModule.redis.set('task:finished_at', Time.now)
    end
  end

  # Sets the progress of the current work
  # It can be used like this in the worker: +WebTaskRunner.work_2_progress = 0.8+
  1000.times do |i|
    i += 1
    define_singleton_method("job_#{i}_progress=") do |progress|
      WebTaskRunner::RedisModule.redis.set("task:worker_#{i}_progress", progress)
    end
  end

  # Starts (or kill and restart) the task
  def self.start_task
    kill_task
    WebTaskRunner::RedisModule.redis.set('task:state', 'working')
    WebTaskRunner::RedisModule.redis.set('task:started_at', Time.now)

    # Set the count of worker that should be started
    jobs_count = @@jobs.count

    # Start the worker here
    @@jobs.each(&:perform_async)

    WebTaskRunner::RedisModule.redis.set('task:task_jobs', jobs_count)
    WebTaskRunner::RedisModule.redis.set('task:working_jobs', jobs_count)

    # Reset the progress of each worker
    jobs_count.times do |i|
      i -= 1
      WebTaskRunner::RedisModule.redis.set("task:worker_#{i}_progress", 0)
    end
  end

  def start_task  # :nodoc:
    WebTaskRunner.start_task
  end

  # Starts the task if it's not running
  def self.start_task_if_idle
    return unless current_state == 'idle'
    start_task
  end

  def start_task_if_idle  # :nodoc:
    WebTaskRunner.start_task_if_idle
  end

  # Kills the running task
  def self.kill_task
    ps = Sidekiq::ProcessSet.new
    ps.each do |p|
      p.stop! if p['busy'] > 0
    end
    sleep(0.5)
    Sidekiq::Queue.new.clear
    Sidekiq::ScheduledSet.new.clear
    Sidekiq::RetrySet.new.clear
    WebTaskRunner.work_ended(all: true)
  end

  def kill_task  # :nodoc:
    WebTaskRunner.kill_task
  end

  # Get the current state
  def self.current_state
    WebTaskRunner::RedisModule.redis.get('task:state') || 'idle'
  end

  def current_state  # :nodoc:
    WebTaskRunner.current_state
  end

  # Get the task progress
  def self.task_progress
    return nil if current_state == 'idle'
    task_jobs = WebTaskRunner::RedisModule.redis.get('task:task_jobs').to_i
    return nil unless task_jobs
    total_progress = 0.0

    task_jobs.times do |i|
      i += 1
      total_progress += WebTaskRunner::RedisModule.redis.get("task:worker_#{i}_progress").to_f
    end

    total_progress / task_jobs.to_f
  end

  def task_progress  # :nodoc:
    WebTaskRunner.task_progress
  end

  # Get the time when the task last started
  def self.task_started_at
    try_to_parse_date_from_redis('task:started_at')
  end

  def task_started_at  # :nodoc:
    WebTaskRunner.task_started_at
  end

  # Get the time when the task last finished
  def self.task_finished_at
    return nil if current_state != 'idle'
    try_to_parse_date_from_redis('task:finished_at')
  end

  def task_finished_at  # :nodoc:
    WebTaskRunner.task_finished_at
  end

  # Get the info of the task
  def self.current_info
    info = { state: current_state }
    info[:task_progress] = task_progress if task_progress
    info[:task_started_at] = task_started_at if task_started_at
    info[:task_finished_at] = task_finished_at if task_finished_at

    info
  end

  def current_info  # :nodoc:
    WebTaskRunner.current_info
  end

  # Get the status of the task runner
  def self.current_status
    info = { state: current_state }

    info
  end

  def current_status  # :nodoc:
    WebTaskRunner.current_status
  end

  private

  def self.try_to_parse_date_from_redis(key)
    Time.parse(WebTaskRunner::RedisModule.redis.get(key))
  rescue
    nil
  end

  def try_to_parse_date_from_redis(key)
    WebTaskRunner.try_to_parse_date_from_redis(key)
  end
end
