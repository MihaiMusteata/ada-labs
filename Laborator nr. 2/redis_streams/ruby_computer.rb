# frozen_string_literal: true

require 'digest/sha2'
require 'json'
require 'redis'

HOST = 'redis'
PORT = 6379
TASK_STREAM = 'puzzle:tasks'
RESULT_STREAM = 'puzzle:results'
GROUP_NAME = 'workers'
CANCEL_KEY = 'puzzle:cancelled'
WINNER_KEY = 'puzzle:winner'
WORKER_NAME = 'Ruby worker'
CONSUMER_NAME = "ruby-#{Process.pid}"
CHECK_INTERVAL = 10_000

def solve_chunk(redis, task)
  sha256 = Digest::SHA256.new
  needle = '0' * task['difficulty']
  checks = 0

  (task['chunk_start']..task['chunk_end']).each do |n|
    if (checks % CHECK_INTERVAL).zero? && redis.get(CANCEL_KEY) == '1'
      return {
        status: 'cancelled',
        worker: WORKER_NAME,
        winner: redis.get(WINNER_KEY)
      }
    end

    solution_candidate = task['string'] + n.to_s
    result = sha256.hexdigest(solution_candidate)

    if result[0...task['difficulty']] == needle
      return {
        status: 'found',
        solution: solution_candidate,
        nonce: n,
        hash: result,
        worker: WORKER_NAME,
        chunk_start: task['chunk_start'],
        chunk_end: task['chunk_end']
      }
    end

    checks += 1
  end

  {
    status: 'not_found',
    worker: WORKER_NAME,
    chunk_start: task['chunk_start'],
    chunk_end: task['chunk_end']
  }
end

def xadd_payload(redis, stream, payload)
  redis.call('XADD', stream, '*', 'payload', payload.to_json)
end

redis = Redis.new(host: HOST, port: PORT)

puts 'Ruby Redis Streams worker started...'
puts "Listening stream: #{TASK_STREAM}, group=#{GROUP_NAME}, consumer=#{CONSUMER_NAME}"

loop do
  begin
    response = redis.call(
      'XREADGROUP', 'GROUP', GROUP_NAME, CONSUMER_NAME,
      'BLOCK', '1000', 'COUNT', '1',
      'STREAMS', TASK_STREAM, '>'
    )
  rescue Redis::CommandError => e
    raise unless e.message.include?('NOGROUP')

    sleep 1
    next
  end

  next if response.nil?

  _stream_name, entries = response.first
  entry_id, fields = entries.first
  task = JSON.parse(Hash[*fields]['payload'])

  puts "Received chunk: #{task['chunk_start']}..#{task['chunk_end']}, difficulty=#{task['difficulty']}"
  result = solve_chunk(redis, task)

  if result[:status] == 'cancelled'
    puts "Searching was stopped..... found by another worker (#{result[:winner] || 'another worker'})"
    redis.call('XACK', TASK_STREAM, GROUP_NAME, entry_id)
    next
  end

  puts "Chunk result by #{WORKER_NAME}: #{result[:status]}, chunk=#{task['chunk_start']}..#{task['chunk_end']}"
  xadd_payload(redis, RESULT_STREAM, result)
  redis.call('XACK', TASK_STREAM, GROUP_NAME, entry_id)
end
