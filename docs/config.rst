Configuration
=============

Configuration is passed as part of the client initialization:

.. code-block:: javascript

    Raven.configure do |config|
      config.dsn = '___DSN___'
      config.attr = 'value'
    end

Optional settings
-----------------

.. describe:: async

    When an error occurs, the notification is immediately sent to Sentry. Raven can be configured to send notifications asynchronously:

    .. code-block:: ruby

        config.async = lambda { |event|
            SentryJob.perform_later(event)
        }

.. describe:: encoding

    While unlikely that you'll need to change it, by default Raven compresses outgoing messages with gzip. This has a slight impact on performance, but due to the size of many Ruby stacktrace it's required for the serve to accept the content.

    To disable gzip, set the encoding to 'json':

    .. code-block:: ruby

        config.encoding = 'json'

.. describe:: environments

    As of v0.10.0, events will be sent to Sentry in all environments. If you do not wish to send events in an environment, we suggest you unset the SENTRY_DSN variable in that environment.

    Alternately, you can configure Raven to run only in certain environments by configuring the environments whitelist. For example, to only run Sentry in production:

    .. code-block:: ruby

        config.environments = %w[ production ]

    Sentry automatically sets the current environment to RAILS_ENV, or if it is not present, RACK_ENV. If you are using Sentry outside of Rack or Rails, you'll need to set the current environment yourself:

    .. code-block:: ruby

        config.current_environment = 'my_cool_environment'

.. describe:: excluded_exceptions

    If you never wish to be notified of certain exceptions, specify 'excluded_exceptions' in your config file.

    In the example below, the exceptions Rails uses to generate 404 responses will be suppressed.

    .. code-block:: ruby

        config.excluded_exceptions = ['ActionController::RoutingError', 'ActiveRecord::RecordNotFound']

    You can find the list of exceptions that are excluded by default in ``Raven::Configuration::IGNORE_DEFAULT``. Remember you'll be overriding those defaults by setting this configuration.

.. describe:: logger

    The name of the logger used by Sentry. Default: ``''``

    .. code-block:: ruby

        config.logger = ::Logger.new(STDOUT)

    Raven respects logger levels.

.. describe:: processors

    If you need to sanitize or pre-process (before its sent to the server) data, you can do so using the Processors implementation. By default, a few processors are installed. The most important is ``Raven::Processor::SanitizeData``, which will attempt to sanitize keys that match various patterns (e.g. password) and values that resemble credit card numbers.

    To specify your own (or to remove the defaults), simply pass them with your configuration:

    .. code-block:: ruby

        config.processors = [Raven::Processor::SanitizeData]

    Check out ``Raven::Processor::SanitizeData`` to see how a Processor is implemented.

    You can also specify values to be sanitized. Any strings matched will be replaced with the string mask (********). One good use for this is to copy Rails' filter_parameters:

    .. code-block:: ruby

        config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)

    By default, Sentry sends up a stacktrace with an exception. This stacktrace may contain data which you may consider to be sensitive, including lines of source code, line numbers, module names, and source paths. To wipe the stacktrace from all error reports, require and add the RemoveStacktrace processor:

    .. code-block:: ruby

        require 'raven/processor/removestacktrace'

        Raven.configure do |config|
          config.processors << Raven::Processor::RemoveStacktrace
        end

    By default, Sentry does not send POST data or cookies if present. To re-enable, remove the respective processor from the chain:

    .. code-block:: ruby

        Raven.configure do |config|
          config.processors -= Raven::Processor::PostData # Do this to send POST data
          config.processors -= Raven::Processor::Cookies # Do this to send cookies by default
        end


.. describe:: release

    Track the version of your application in Sentry.

    We guess the release intelligently in the following order of preference:

    * Heroku's HEROKU_SLUG_COMMIT environment variable
    * Reading from the REVISION file in the app root
    * Commit SHA of the last commit (git)

    .. code-block:: ruby

        config.release = '721e41770371db95eee98ca2707686226b993eda'

.. describe:: should_capture

    By providing a proc or lambda, you can control what events are captured. Events are passed to the Proc or lambda you provide - returning false will stop the event from sending to Sentry:

    .. code-block:: ruby

        config.should_capture = Proc.new { |e| true unless e.contains_sensitive_info? }

.. describe:: silence_ready

    Upon start, Raven will write the following message to the log at the INFO level:

    ``
    ** [out :: hostname.example.com] I, [2014-07-22T15:32:57.498368 #30897]  INFO -- : ** [Raven] Raven 0.9.4 ready to catch errors"
    ``

    You can turn off this message:

    .. code-block:: ruby

        config.silence_ready = true

.. describe:: ssl_verification

    By default SSL certificate verification is enabled in the client. It can be disabled.

    .. code-block:: ruby

        config.ssl_verification = false

.. describe:: tags

    Default tags to send with each event.

    .. code-block:: ruby

        config.tags = { environment: Rails.env }

Environment Variables
---------------------

.. describe:: SENTRY_DSN

    After you complete setting up a project, you'll be given a value which we call a DSN, or Data Source Name. It looks a lot like a standard URL, but it's actually just a representation of the configuration required by Raven (the Sentry client). It consists of a few pieces, including the protocol, public and secret keys, the server address, and the project identifier.

    With Raven, you may either set the SENTRY_DSN environment variable (recommended), or set your DSN manually in a config block:

    .. code-block:: ruby

        # in Rails, this might be in config/initializers/sentry.rb
        Raven.configure do |config|
          config.dsn = 'http://public:secret@example.com/project-id'
        end
