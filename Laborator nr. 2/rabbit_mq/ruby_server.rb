# frozen_string_literal: true

require 'bunny'
require 'securerandom'
require 'json'

user = 'guest'
password = 'guest'
host = 'rabbitmq'
port = 5672
queue_name = 'crypto-puzzle-inquiries'
cancel_exchange_name = 'crypto-puzzle-cancel'

workers_count = 3

connection = Bunny.new(hostname: host, port: port, username: user, password: password)
connection.start

lock = Mutex.new
condition = ConditionVariable.new

received_response = false
final_response = nil

channel = connection.create_channel
exchange = channel.default_exchange
cancel_exchange = channel.fanout(cancel_exchange_name)
queue = channel.queue(queue_name, auto_delete: true)
reply_queue = channel.queue('', auto_delete: true, exclusive: true)

reply_queue.subscribe do |_delivery_info, _properties, payload|
  lock.synchronize do
    unless received_response
      received_response = true
      final_response = payload
      condition.signal
    end
  end
end

begin
  loop do
    puts 'Press Ctrl+C to exit'
    puts 'Enter difficulty of puzzle from 1 to 8:'

    line = $stdin.gets
    break if line.nil?

    difficulty = line.to_i

    if (1..8).include?(difficulty)
      received_response = false
      final_response = nil

      correlation_id = SecureRandom.uuid
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      workers_count.times do |worker_index|
        payload = {
          string: 'Hello World',
          difficulty: difficulty,
          start: worker_index,
          step: workers_count
        }

        exchange.publish(
          payload.to_json,
          routing_key: queue.name,
          correlation_id: correlation_id,
          reply_to: reply_queue.name
        )

        puts "Sent task: start=#{worker_index}, step=#{workers_count}"
      end

      puts 'Computation in progress...'

      lock.synchronize do
        condition.wait(lock) until received_response
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      response = JSON.parse(final_response)
      cancel_exchange.publish(
        {
          correlation_id: correlation_id,
          winner: response['worker']
        }.to_json
      )

      puts "Response to crypto-puzzle is: #{final_response}"
      puts "Elapsed time: #{(elapsed * 1000).round(2)} ms"
    else
      puts "Incorrect value. You've introduced #{difficulty}. Valid range is 1..8"
    end
  end
rescue Interrupt => _e
  channel.close
  connection.close
  exit(0)
end
