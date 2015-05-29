if defined? Sinatra::Application
  class WebTaskRunner < Sinatra::Application
    VERSION = "0.0.1"
  end
else
  class WebTaskRunner
    VERSION = "0.0.1"
  end
end
