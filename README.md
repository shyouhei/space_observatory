# SpaceObservatory

This is an easy add-on for you to observe your ObjectSpace.

## Main Features

- Pure ruby.  NO C extensions.
- Drop-in design that requires NO modifications to your program.
- Minimal overhead.  Does all jobs except data collection in a separate process.
- Native support Rails, Sinatra, and non-Web daemons.

## Installation

As usual.

**NOTE** however that as of this writing, WEBrick do not support websockets (necessary for this lib).  You need a websockets-aware rack handler like Puma, Passanger, whatever.

## Usage

### on Rails

```ruby
gem 'space_observatory', require: 'space_observatory/railtie'
```

And you are done.

### Pure Rack / Sinatra / Padrino etc

```ruby
gem 'space_observatory', require: 'space_observatory/rack_middleware'
```

Also in your `config.ru` file add:

```ruby
use SpaceObservatory::RackMiddleware
```

### Versatile use case including non-Web daemons

```bash
bundle exec with-space-observatory.rb --port=1234 -- ruby bin/rails server --port=5678
```

This command starts two HTTP servers on ports 1234 and 5678 each.  1234 (for this case) is for probing object space of rails server which listens port 5678.

`with-space-observatory.rb --help` might expose more option(s).

## TODOs

- Probing is slow.  Should cache.
- JSON is valid, but not that pretty.
