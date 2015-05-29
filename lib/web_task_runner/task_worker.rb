require 'sinatra'
require 'sidekiq'
require 'sidekiq-status'

require_relative '../web_task_runner.rb'

class WebTaskRunner < Sinatra::Application
  class TaskWorker
    include Sidekiq::Worker
    include Sidekiq::Status::Worker

    def perform
      return if WebTaskRunner.current_state == 'idle'

      exec

      puts "Job ##{job_number} done."
      WebTaskRunner.job_ended
    end

    def job_number
      job_number = 0
      klass = self.class
      WebTaskRunner.jobs.each_with_index do |job, i|
        if job == klass
          job_number = i + 1
          break
        end
      end
      job_number
    end

    def exec
      puts <<-EOF
        Define the work in #{self.class}#exec!
      EOF
    end
  end
end
