# frozen_string_literal: true

require 'json'
require 'redis'

HOST = 'redis'
PORT = 6379
TASK_STREAM = 'puzzle:tasks'
RESULT_STREAM = 'puzzle:results'
GROUP_NAME = 'workers'
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

def create_group(redis)
  redis.call('XGROUP', 'CREATE', TASK_STREAM, GROUP_NAME, '0', 'MKSTREAM')
rescue Redis::CommandError => e
  raise unless e.message.include?('BUSYGROUP')
end

def xadd_payload(redis, stream, payload)
  redis.call('XADD', stream, '*', 'payload', payload.to_json)
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

    redis.del(TASK_STREAM, RESULT_STREAM, CANCEL_KEY, WINNER_KEY)
    create_group(redis)

    next_chunk_start = 0
    in_flight = 0
    last_result_id = '0-0'

    publish_next_chunk = lambda do
      chunk_start = next_chunk_start
      chunk_end = chunk_start + CHUNK_SIZE - 1
      next_chunk_start = chunk_end + 1

      xadd_payload(redis, TASK_STREAM, build_chunk_payload(difficulty, chunk_start, chunk_end))
      in_flight += 1
      puts "Sent chunk: #{chunk_start}..#{chunk_end}"
    end

    WINDOW_SIZE.times { publish_next_chunk.call }

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    puts 'Computation in progress...'

    loop do
      response = redis.call('XREAD', 'BLOCK', '0', 'STREAMS', RESULT_STREAM, last_result_id)
      _stream_name, entries = response.first
      entry_id, fields = entries.first
      last_result_id = entry_id

      result = JSON.parse(Hash[*fields]['payload'])
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
