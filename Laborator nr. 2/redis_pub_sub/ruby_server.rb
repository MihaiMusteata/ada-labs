# frozen_string_literal: true

require 'json'
require 'redis'

HOST = 'redis'
PORT = 6379
REQUEST_CHANNEL = 'puzzle:requests'
RESULT_CHANNEL = 'puzzle:results'
CANCEL_CHANNEL = 'puzzle:cancel'
TASK_CHANNEL_PREFIX = 'puzzle:tasks'
CHUNK_SIZE = 500_000

def build_chunk_payload(difficulty, chunk_start, chunk_end)
  {
    string: 'Hello World',
    difficulty: difficulty,
    chunk_start: chunk_start,
    chunk_end: chunk_end
  }
end

publisher = Redis.new(host: HOST, port: PORT)

begin
  loop do
    puts 'Press Ctrl+C to exit'
    puts 'Enter difficulty of puzzle from 1 to 8:'

    line = $stdin.gets
    break if line.nil?

    difficulty = line.to_i

    unless (1..8).include?(difficulty)
      puts "Incorrect value. You've introduced #{difficulty}. Valid range is 1..8"
      next
    end

    lock = Mutex.new
    condition = ConditionVariable.new
    found = false
    final_response = nil
    next_chunk_start = 0
    busy_workers = {}
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    subscriber = Redis.new(host: HOST, port: PORT)
    listener = Thread.new do
      begin
        subscriber.subscribe(REQUEST_CHANNEL, RESULT_CHANNEL) do |on|
          on.message do |channel, message|
            if channel == REQUEST_CHANNEL
              request = JSON.parse(message)

              lock.synchronize do
                next if found
                next if busy_workers[request['worker_id']]

                chunk_start = next_chunk_start
                chunk_end = chunk_start + CHUNK_SIZE - 1
                next_chunk_start = chunk_end + 1
                busy_workers[request['worker_id']] = true

                publisher.publish(
                  "#{TASK_CHANNEL_PREFIX}:#{request['worker_id']}",
                  build_chunk_payload(difficulty, chunk_start, chunk_end).to_json
                )

                puts "Sent chunk to #{request['worker']}: #{chunk_start}..#{chunk_end}"
              end
            elsif channel == RESULT_CHANNEL
              result = JSON.parse(message)

              lock.synchronize do
                busy_workers.delete(result['worker_id'])

                next unless result['status'] == 'found'
                next if found

                found = true
                final_response = result
                publisher.publish(
                  CANCEL_CHANNEL,
                  {
                    winner: result['worker']
                  }.to_json
                )
                condition.signal
              end
            end
          end
        end
      rescue IOError, RedisClient::ConnectionError
        # Expected when the server stops the subscription after a solution is found.
      end
    end
    listener.report_on_exception = false

    puts 'Computation in progress...'
    puts 'Waiting for worker requests...'

    lock.synchronize do
      condition.wait(lock) until found
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    puts "Response to crypto-puzzle is: #{final_response.to_json}"
    puts "Elapsed time: #{(elapsed * 1000).round(2)} ms"

    listener.kill
    listener.join
    subscriber.close
  end
rescue Interrupt
  exit(0)
end
