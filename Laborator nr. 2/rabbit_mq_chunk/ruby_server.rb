# frozen_string_literal: true

require 'bunny'
require 'json'
require 'securerandom'

USER = 'guest'
PASSWORD = 'guest'
HOST = 'rabbitmq'
PORT = 5672
QUEUE_NAME = 'crypto-puzzle-chunks'
CANCEL_EXCHANGE_NAME = 'crypto-puzzle-cancel'
WORKERS_COUNT = 3
CHUNK_SIZE = 500_000
WINDOW_SIZE = WORKERS_COUNT * 2

def build_chunk_payload(difficulty, chunk_start, chunk_end)
  {
    string: 'Hello World',
    difficulty: difficulty,
    chunk_start: chunk_start,
    chunk_end: chunk_end
  }
end

connection = Bunny.new(hostname: HOST, port: PORT, username: USER, password: PASSWORD)
connection.start

channel = connection.create_channel
exchange = channel.default_exchange
cancel_exchange = channel.fanout(CANCEL_EXCHANGE_NAME)
queue = channel.queue(QUEUE_NAME, auto_delete: true)
reply_queue = channel.queue('', exclusive: true, auto_delete: true)

lock = Mutex.new
condition = ConditionVariable.new

found = false
final_response = nil
current_correlation_id = nil
difficulty = nil
next_chunk_start = 0
in_flight = 0

publish_next_chunk = lambda do
  chunk_start = next_chunk_start
  chunk_end = chunk_start + CHUNK_SIZE - 1
  next_chunk_start = chunk_end + 1

  exchange.publish(
    build_chunk_payload(difficulty, chunk_start, chunk_end).to_json,
    routing_key: queue.name,
    correlation_id: current_correlation_id,
    reply_to: reply_queue.name
  )

  in_flight += 1
  puts "Sent chunk: #{chunk_start}..#{chunk_end}"
end

reply_queue.subscribe(manual_ack: true) do |delivery_info, properties, payload|
  message = JSON.parse(payload)

  lock.synchronize do
    next if properties.correlation_id != current_correlation_id

    in_flight -= 1 if in_flight.positive?

    if message['status'] == 'found' && !found
      found = true
      final_response = message

      cancel_exchange.publish(
        {
          correlation_id: current_correlation_id,
          winner: message['worker']
        }.to_json
      )

      condition.signal
    elsif !found
      publish_next_chunk.call while in_flight < WINDOW_SIZE
    end
  end

  channel.ack(delivery_info.delivery_tag)
end

begin
  loop do
    puts 'Press Ctrl+C to exit'
    puts 'Enter difficulty of puzzle from 1 to 8:'

    line = $stdin.gets
    break if line.nil?

    difficulty = line.to_i

    if (1..8).include?(difficulty)
      lock.synchronize do
        found = false
        final_response = nil
        current_correlation_id = SecureRandom.uuid
        next_chunk_start = 0
        in_flight = 0

        WINDOW_SIZE.times { publish_next_chunk.call }
      end

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      puts 'Computation in progress...'

      lock.synchronize do
        condition.wait(lock) until found
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      puts "Response to crypto-puzzle is: #{final_response.to_json}"
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
