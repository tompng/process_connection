```ruby
gem 'process_connection', github: 'tompng/process_connection'
```

```ruby
# unicorn_config.rb
ProcessConnection.start_master
```

```ruby
# after fork
ProcessConnection.start do |message|
  # do something
  'OK' # response
end
```

```ruby
# broadcast
ProcessConnection.broadcast message, response: true, include_self: true
# if response: true => array of result (blocking)
# if response: false => number of workers (nonblocking)
```
