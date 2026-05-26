# frozen_string_literal: true

require 'bunny'
require 'securerandom'
require 'json'
user = 'guest'
password = 'guest'
host = 'rabbitmq:5672'
queue_name = 'crypto-puzzle-inquiries'
reply_queue_name = 'crypto-puzzle-responses'

connection = Bunny.new "amqp://#{user}:#{password}@#{host}"
connection.start

lock = Mutex.new
condition = ConditionVariable.new

channel = connection.create_channel
exchange = channel.default_exchange
queue = channel.queue(queue_name, auto_delete: true)
reply_queue = channel.queue(reply_queue_name, auto_delete: true, exclusive: true)
reply_queue.subscribe do |_delivery_info, _properties, payload|
  puts "Response to crypto-puzzle is: #{payload}"
  lock.synchronize { condition.signal }
end

begin
  loop do
    puts 'Press Ctrl+C to exit'
    puts 'Enter difficulty of puzzle from 1 to 8:'

    difficulty = $stdin.gets.to_i
    if (1..8).include?(difficulty)
      payload = { string: 'Hello World', difficulty: difficulty }
      exchange.publish(payload.to_json, routing_key: queue.name, correlation_id: SecureRandom.uuid, reply_to: reply_queue.name)
      puts 'Computation in progress...'
      lock.synchronize { condition.wait(lock) }
    else
      puts "Incorrect value. You've introduced #{difficulty}. Valid range is 1..8"
    end
  end
rescue Interrupt => _e
  channel.close
  connection.close
  exit(0)
end
