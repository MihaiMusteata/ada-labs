# frozen_string_literal: true

require 'json'
require 'redis'

HOST = 'redis'
PORT = 6379
TASKS_QUEUE = 'puzzle:tasks'
RESULTS_QUEUE = 'puzzle:results'
CANCEL_KEY = 'puzzle:cancelled'
WINNER_KEY = 'puzzle:winner'
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

redis = Redis.new(host: HOST, port: PORT)

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

    redis.del(TASKS_QUEUE, RESULTS_QUEUE, CANCEL_KEY, WINNER_KEY)

    next_chunk_start = 0
    in_flight = 0

    publish_next_chunk = lambda do
      chunk_start = next_chunk_start
      chunk_end = chunk_start + CHUNK_SIZE - 1
      next_chunk_start = chunk_end + 1

      redis.rpush(TASKS_QUEUE, build_chunk_payload(difficulty, chunk_start, chunk_end).to_json)
      in_flight += 1
      puts "Sent chunk: #{chunk_start}..#{chunk_end}"
    end

    WINDOW_SIZE.times { publish_next_chunk.call }

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    puts 'Computation in progress...'

    loop do
      _queue, payload = redis.blpop(RESULTS_QUEUE, 0)
      result = JSON.parse(payload)
      in_flight -= 1 if in_flight.positive?

      if result['status'] == 'found'
        redis.set(CANCEL_KEY, '1')
        redis.set(WINNER_KEY, result['worker'])

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        puts "Response to crypto-puzzle is: #{result.to_json}"
        puts "Elapsed time: #{(elapsed * 1000).round(2)} ms"
        break
      end

      publish_next_chunk.call while in_flight < WINDOW_SIZE && redis.get(CANCEL_KEY) != '1'
    end
  end
rescue Interrupt
  exit(0)
end
