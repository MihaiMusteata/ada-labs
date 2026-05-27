# frozen_string_literal: true

require 'digest/sha2'
require 'json'
require 'redis'

HOST = 'redis'
PORT = 6379
TASKS_QUEUE = 'puzzle:tasks'
RESULTS_QUEUE = 'puzzle:results'
CANCEL_KEY = 'puzzle:cancelled'
WINNER_KEY = 'puzzle:winner'
WORKER_NAME = 'Ruby worker'
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

redis = Redis.new(host: HOST, port: PORT)

puts 'Ruby Redis Lists worker started...'
puts "Listening queue: #{TASKS_QUEUE}"

loop do
  item = redis.blpop(TASKS_QUEUE, 1)
  next if item.nil?

  _queue, payload = item
  task = JSON.parse(payload)

  puts "Received chunk: #{task['chunk_start']}..#{task['chunk_end']}, difficulty=#{task['difficulty']}"
  result = solve_chunk(redis, task)

  if result[:status] == 'cancelled'
    puts "Searching was stopped..... found by another worker (#{result[:winner] || 'another worker'})"
    next
  end

  puts "Chunk result by #{WORKER_NAME}: #{result[:status]}, chunk=#{task['chunk_start']}..#{task['chunk_end']}"
  redis.rpush(RESULTS_QUEUE, result.to_json)
end
