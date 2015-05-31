# WebTaskRunner [![Gem Version](https://badge.fury.io/rb/web_task_runner.svg)](http://badge.fury.io/rb/web_task_runner) [![Build Status](https://travis-ci.org/Neson/web_task_runner.svg?branch=master)](https://travis-ci.org/Neson/web_task_runner) [![Documentation Status](http://inch-ci.org/github/Neson/web_task_runner.svg?branch=master)](http://inch-ci.org/github/Neson/web_task_runner)

Web wrapper to run a specific task with [Sidekiq](http://sidekiq.org/).
Provides HTTP API to start, stop, get status of the task running in background,
and is deployable to cloud platforms like Heroku.

A task is set of jobs for an specific purpose, like crawling a website, syncing
data... etc. For easy manageability, one task runner only provides running one
separate task.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'web_task_runner'
```

And then execute:

    $ bundle


## Requirements

Redis is required to run the background jobs. Make sure you have one, and set
the `REDIS_URL` environment variable to the Redis URL.

## Usage

Just `require 'web_task_runner'` and append jobs to it
(`WebTaskRunner.jobs << SomeWork`). Then you'll have a Rack app `WebTaskRunner`
providing web APIs ready to be mounted. Configurations `REDIS_URL`, `API_KEY`
and `REDIS_NAMESPACE` can be set through environment variables.

Please refer the [Getting Start](#getting-start) section for more details.

### API Endpoints

Note that all APIs has been secured with the `API_KEY`. Each request should
pass the matching `API_KEY` with the `key` parameter
(e.g.: `https://example.app/?key=secreat_key`), otherwise an `401 Unauthorized`
error will be returned.

#### `GET /`

Returns the information of the task runner.

#### `GET /status`

Returns the current (or last) status of running task.

```json
HTTP/1.1 200 OK

{
  "status": "processing",
  "progress": 0.52,
  "started_at": "2015-05-29 22:36:35 +0000"
}
```

 - status: can be `processing`, `ok` or `error`
 - progress: an float representing the current working progress, presented only
             if the task is currently in progress
 - started_at: time of when the task has been started
 - finished_at: time of when the task has finished, presented only
                if the last task is finished

#### `GET /start`

Start to run the task (if the task is not currently running).

```json
HTTP/1.1 202 Accepted

{
  "status": "processing",
  "link": "https://example.app/status?key=secreat_key"
}
```

 - status: must be `processing`, since the task will be run asynchronously
 - link: URL for monitoring the started task

#### `GET /stop`

Force stop the current running task.

```json
HTTP/1.1 200 OK

{
  "status": "error",
  "link": "https://example.app/status?key=secreat_key",
  "started_at": "2015-05-29 22:36:35 +0000",
  "finished_at": "2015-05-29 23:12:48 +0000"
}
```

## Getting Start

Create and `cd` into a new folder to place the task runner app. After adding
`gem 'web_task_runner'` into your project's `Gemfile`
(`echo "gem 'web_task_runner'" >> Gemfile`), run the `bundle` command to
install it, then proceed on the following to set it up:

### Set the Environment Variables

The following environment variables should be configured for the task runner
app to run, you can set it using `$ export` or save them into a file called
`.env` right under the project folder.

 - `REDIS_URL`: specify the Redis to connect to
 - `API_KEY`: chose a secret key for accessing the web API
 - `REDIS_NAMESPACE`: _(optional)_ namespacing Redis keys

### Create The App

Create an file, for instance, `./app.rb` (`touch app.rb`) to place the app.

Edit that file to require the `web_task_runner` gem:

```ruby
# app.rb

require 'web_task_runner'
```

### Add Jobs To The Task

A task may contain many jobs, which can be working on concurrently. When the
task starts, all the jobs will be carried out, run (and rerun if faild) with
Sidekiq. The task will end after every job has been done.

You can define new jobs by creating a class inheriting
`WebTaskRunner::TaskWorker`:

```ruby
# app.rb

require 'web_task_runner'

class MyWorkOne < WebTaskRunner::TaskWorker
end
```

The actual work of that job can should defined in the instance method `#exec`
of the class:

```ruby
# app.rb

require 'web_task_runner'

class MyWorkOne < WebTaskRunner::TaskWorker
  def exec
    # yes - you can access all parameters passed with the request
    x = params[:time] || 1
    # sleep x second(s) for ten times
    10.times do |i|
      sleep(x)
      raise if Random.rand(100) < 2  # simulate errors
    end
  end
end
```

Progress of that work may be reported with the `WebTaskRunner.job_n_progress=`
method (`n` is the serial number of job, e.g.: `1`) while the job is running:

```ruby
# app.rb

require 'web_task_runner'

class MyWorkOne < WebTaskRunner::TaskWorker
  def exec
    # yes - you can access all parameters passed with the request
    x = params[:time] || 1
    # sleep x second(s) for ten times
    10.times do |i|
      sleep(x)
      raise if Random.rand(100) < 2  # simulate errors
      # report the current progress
      WebTaskRunner.job_1_progress = (i + 1) / 10.0
    end
  end
end
```

At last, append the job to the task using `WebTaskRunner.jobs.<<`:

```ruby
# app.rb

require 'web_task_runner'

class MyWorkOne < WebTaskRunner::TaskWorker
  def exec
    # ...
  end
end

# append the job to task runner
WebTaskRunner.jobs << MyWorkOne
```

### Construct Deployable Application

You may need other files to make your application deployable, for instance,
a `config.ru` Rack configuration file, a `Procfile` to specify process types.

The `config.ru` file can be set up like this:

```ruby
# config.ru

require './app'  # require your application
run Rack::URLMap.new('/' => WebTaskRunner)
```

Sidekiq also provides an web monitoring interface that you can mount. If you
choose to use it, your `config.ru` may be like this:

```ruby
# config.ru

require './app'  # require your application
require 'sidekiq/web'  # require sidekiq web interface

# secure the web interface using the API key as password
Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  [user, password] == ["admin", ENV['API_KEY']]
end

# mount both WebTaskRunner and Sidekiq::Web
run Rack::URLMap.new('/' => WebTaskRunner, '/sidekiq' => Sidekiq::Web)
```

The next will be `Procfile`, which may be like this:

```
web: bundle exec thin start -p $PORT
worker: bundle exec sidekiq -c 10 -t 0 -v -r ./app.rb
```

### Up And Running

Now your application is ready for running, it can be deployed to heroku by a
`git push`, add an Redis addon, and scale up both web and worker dynos. Or
run it locally using `foreman`, or even run the processes manually:

```bash
$ bundle exec thin start -p 5000 & ; bundle exec sidekiq -c 10 -t 0 -v -r ./app.rb &
```

Then, use the API endpoints to control or monitor the task runner. Each
request should be called with an `key` parameter containing the same API key
specified aboved in the `API_KEY` environment variable.

To get the current status, visit `/`:

```http
GET http://localhost:5000/?key=some_secret_key

HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 122
Content-Type: text/html;charset=utf-8

{
  "state": "idle",
  "task_started_at": "2015-05-29 15:49:41 +0800",
  "task_finished_at": "2015-05-29 15:49:51 +0800"
}
```

To start running the task, visit `/start`.

To kill the task that is currently running, visit `/kill`.

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `bin/console` for an interactive prompt that will allow you
to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release` to create a git tag for the version, push git
commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/Neson/web_task_runner/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
