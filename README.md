# Raven-Ruby

[![Gem Version](https://img.shields.io/gem/v/sentry-raven.svg)](https://rubygems.org/gems/sentry-raven)
[![Build Status](https://img.shields.io/travis/getsentry/raven-ruby/master.svg)](https://travis-ci.org/getsentry/raven-ruby)

A client and integration layer for the [Sentry](https://github.com/getsentry/sentry) error reporting API.

## Requirements

We test on Ruby 1.9, 2.2 and 2.3 at the latest patchlevel/teeny version. Our Rails integration works with Rails 4.2+. JRuby support is experimental - check TravisCI to see if the build is passing or failing.

## Getting Started

### Install

```ruby
gem "sentry-raven"
```

### Raven only runs when SENTRY_DSN is set

Raven will capture and send exceptions to the Sentry server whenever its DSN is set. This makes environment-based configuration easy - if you don't want to send errors in a certain environment, just don't set the DSN in that environment!

```bash
# Set your SENTRY_DSN environment variable.
export SENTRY_DSN=http://public:secret@example.com/project-id
```
```ruby
# Or you can configure the client in the code (not recommended - keep your DSN secret!)
Raven.configure do |config|
  config.dsn = 'http://public:secret@example.com/project-id'
end
```

### Raven doesn't report some kinds of data by default.

Raven ignores some exceptions by default - most of these are related to 404s or controller actions not being found. [For a complete list, see the `IGNORE_DEFAULT` constant](https://github.com/getsentry/raven-ruby/blob/master/lib/raven/configuration.rb).

Raven doesn't report POST data or cookies by default. In addition, it will attempt to remove any obviously sensitive data, such as credit card or Social Security numbers. For more information about how Sentry processes your data, [check out the documentation on the `processors` config setting.](https://docs.getsentry.com/hosted/clients/ruby/config/)

### Call

If you use Rails, you're already done - no more configuration required! Check [Integrations](https://docs.getsentry.com/hosted/clients/ruby/integrations/) for more details on other gems Sentry integrates with automatically.

Otherwise, Raven supports two methods of capturing exceptions:

```ruby
Raven.capture do
  # capture any exceptions which happen during execution of this block
  1 / 0
end

begin
  1 / 0
rescue ZeroDivisionError => exception
  Raven.capture_exception(exception)
end
```

### More configuration

You're all set - but there's a few more settings you may want to know about too!

#### DSN

While we advise that you set your Sentry DSN through the `SENTRY_DSN` environment
variable, there are two other configuration settings for controlling Raven:

```ruby
# DSN can be configured as a config setting instead.
# Place in config/initializers or similar.
Raven.configure do |config|
  config.dsn = 'your_dsn'
end
```

And, while not necessary if using `SENTRY_DSN`, you can also provide an `environments`
setting. Raven will only capture events when `RACK_ENV` or `RAILS_ENV` matches
an environment in the list.

```ruby
Raven.configure do |config|
  config.environments = %w[staging production]
end
```

#### async

When an error or message occurs, the notification is immediately sent to Sentry. Raven can be configured to send asynchronously:

```ruby
config.async = lambda { |event|
  Thread.new { Raven.send_event(event) }
}
```

Using a thread to send events will be adequate for truly parallel Ruby platforms such as JRuby, though the benefit on MRI/CRuby will be limited. If the async callback raises an exception, Raven will attempt to send synchronously.

We recommend creating a background job, using your background job processor, that will send Sentry notifications in the background. Rather than enqueuing an entire Raven::Event object, we recommend providing the Hash representation of an event as a job argument. Here’s an example for ActiveJob:

```ruby
config.async = lambda { |event|
  SentryJob.perform_later(event.to_hash)
}
class SentryJob < ActiveJob::Base
  queue_as :default

  def perform(event)
    Raven.send_event(event)
  end
end
```

#### transport_failure_callback

If Raven fails to send an event to Sentry for any reason (either the Sentry server has returned a 4XX or 5XX response), this Proc or lambda will be called.

```ruby
config.transport_failure_callback = lambda { |event|
  AdminMailer.email_admins("Oh god, it's on fire!", event).deliver_later
}
```

#### Context

Much of the usefulness of Sentry comes from additional context data with the events. Raven makes this very convenient by providing methods to set thread local context data that is then submitted automatically with all events.

There are three primary methods for providing request context:

```ruby
# bind the logged in user
Raven.user_context email: 'foo@example.com'

# tag the request with something interesting
Raven.tags_context interesting: 'yes'

# provide a bit of additional context
Raven.extra_context happiness: 'very'
```

For more information, see [Context](https://docs.sentry.io/clients/ruby/context/).

## More Information

* [Documentation](https://docs.getsentry.com/hosted/clients/ruby/)
* [Bug Tracker](https://github.com/getsentry/raven-ruby/issues>)
* [Code](https://github.com/getsentry/raven-ruby>)
* [Mailing List](https://groups.google.com/group/getsentry>)
* [IRC](irc://irc.freenode.net/sentry>)  (irc.freenode.net, #sentry)
