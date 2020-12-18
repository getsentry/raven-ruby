# Changelog

## 4.1.0

- Separate rack integration [#1138](https://github.com/getsentry/sentry-ruby/pull/1138)
  - Fixes [#1136](https://github.com/getsentry/sentry-ruby/pull/1136)
- Fix event sampling [#1144](https://github.com/getsentry/sentry-ruby/pull/1144)
- Merge & rename 2 Rack middlewares [#1147](https://github.com/getsentry/sentry-ruby/pull/1147)
  - Fixes [#1153](https://github.com/getsentry/sentry-ruby/pull/1153)
  - Removed `Sentry::Rack::Tracing` middleware and renamed `Sentry::Rack::CaptureException` to `Sentry::Rack::CaptureExceptions`.
- Deep-copy spans [#1148](https://github.com/getsentry/sentry-ruby/pull/1148)
- Move span recorder related code from Span to Transaction [#1149](https://github.com/getsentry/sentry-ruby/pull/1149)
- Check SDK initialization before running integrations [#1151](https://github.com/getsentry/sentry-ruby/pull/1151)
  - Fixes [#1145](https://github.com/getsentry/sentry-ruby/pull/1145)
- Refactor transport [#1154](https://github.com/getsentry/sentry-ruby/pull/1154)
- Implement non-blocking event sending [#1155](https://github.com/getsentry/sentry-ruby/pull/1155)
  - Added `background_worker_threads` configuration option.

### Noticeable Changes

#### Middleware Changes

`Sentry::Rack::Tracing` is now removed. And `Sentry::Rack::CaptureException` has been renamed to `Sentry::Rack::CaptureExceptions`.

#### Events Are Sent Asynchronously

`sentry-ruby` now sends events asynchronously by default. The functionality works like this: 

1. When the SDK is initialized, a `Sentry::BackgroundWorker` will be initialized too.
2. When an event is passed to `Client#capture_event`, instead of sending it directly with `Client#send_event`, we'll let the worker do it.
3. The worker will have a number of threads. And the one of the idle threads will pick the job and call `Client#send_event`.
    - If all the threads are busy, new jobs will be put into a queue, which has a limit of 30.
    - If the queue size is exceeded, new events will be dropped.

However, if you still prefer to use your own async approach, that's totally fine. If you have `config.async` set, the worker won't initialize a thread pool and won't be used either.

This functionality also introduces a new `background_worker_threads` config option. It allows you to decide how many threads should the worker hold. By default, the value will be the number of the processors your machine has. For example, if your machine has 4 processors, the value would be 4.

Of course, you can always override the value to fit your use cases, like

```ruby
config.background_worker_threads = 5 # the worker will have 5 threads for sending events
```

You can also disable this new non-blocking behaviour by giving a `0` value:

```ruby
config.background_worker_threads = 0 # all events will be sent synchronously
```

## 4.0.1

- Add rake integration: [1137](https://github.com/getsentry/sentry-ruby/pull/1137)
- Make Event's interfaces accessible: [1135](https://github.com/getsentry/sentry-ruby/pull/1135)
- ActiveSupportLogger should only record events that has a started time: [1132](https://github.com/getsentry/sentry-ruby/pull/1132)

## 4.0.0

- Only documents update for the official release and no API/feature changes.

## 0.3.0

- Major API changes: [1123](https://github.com/getsentry/sentry-ruby/pull/1123)
- Support event hint: [1122](https://github.com/getsentry/sentry-ruby/pull/1122)
- Add request-id tag to events: [1120](https://github.com/getsentry/sentry-ruby/pull/1120) (by @tvec)

## 0.2.0

- Multiple fixes and refactorings
- Tracing support

## 0.1.3

Fix require reference

## 0.1.2

- Fix: Fix async callback [1098](https://github.com/getsentry/sentry-ruby/pull/1098)
- Refactor: Some code cleanup [1100](https://github.com/getsentry/sentry-ruby/pull/1100)
- Refactor: Remove Event options [1101](https://github.com/getsentry/sentry-ruby/pull/1101)

## 0.1.1

- Feature: Allow passing custom scope to Hub#capture* helpers [1086](https://github.com/getsentry/sentry-ruby/pull/1086)

## 0.1.0

First version

