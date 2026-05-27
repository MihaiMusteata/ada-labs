# frozen_string_literal: true

require 'digest/sha2'
require 'json'
require 'redis'

HOST = 'redis'
PORT = 6379
REQUEST_CHANNEL = 'puzzle:requests'
RESULT_CHANNEL = 'puzzle:results'
CANCEL_CHANNEL = 'puzzle:cancel'
TASK_CHANNEL_PREFIX = 'puzzle:tasks'
WORKER_NAME = 'Ruby worker'
WORKER_ID = "ruby-#{Process.pid}"
CHECK_INTERVAL = 10_000

def solve_chunk(cancelled, task)
  sha256 = Digest::SHA256.new
  needle = '0' * task['difficulty']
  checks = 0

  (task['chunk_start']..task['chunk_end']).each do |n|
    if (checks % CHECK_INTERVAL).zero? && cancelled.call
      return {
        status: 'cancelled',
        worker: WORKER_NAME
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

publisher = Redis.new(host: HOST, port: PORT)
task_subscriber = Redis.new(host: HOST, port: PORT)
cancel_subscriber = Redis.new(host: HOST, port: PORT)

lock = Mutex.new
idle = true
cancelled = false
winner = nil

Thread.new do
  cancel_subscriber.subscribe(CANCEL_CHANNEL) do |on|
    on.message do |_channel, message|
      cancel_message = JSON.parse(message)

      lock.synchronize do
        cancelled = true
        winner = cancel_message['winner']
      end
    end
  end
end

Thread.new do
  loop do
    should_request = lock.synchronize { idle }

    if should_request
      publisher.publish(
        REQUEST_CHANNEL,
        {
          worker_id: WORKER_ID,
          worker: WORKER_NAME
        }.to_json
      )
    end

    sleep 1
  end
end

puts 'Ruby Redis Pub/Sub worker started...'
puts "Listening channel: #{TASK_CHANNEL_PREFIX}:#{WORKER_ID}"

task_subscriber.subscribe("#{TASK_CHANNEL_PREFIX}:#{WORKER_ID}") do |on|
  on.message do |_channel, message|
    lock.synchronize do
      idle = false
      cancelled = false
      winner = nil
    end

    task = JSON.parse(message)
    puts "Received chunk: #{task['chunk_start']}..#{task['chunk_end']}, difficulty=#{task['difficulty']}"

    result = solve_chunk(lambda { lock.synchronize { cancelled } }, task)

    if result[:status] == 'cancelled'
      stopped_by = lock.synchronize { winner || 'another worker' }
      puts "Searching was stopped..... found by another worker (#{stopped_by})"
      lock.synchronize do
        idle = true
      end
      next
    end

    puts "Chunk result by #{WORKER_NAME}: #{result[:status]}, chunk=#{task['chunk_start']}..#{task['chunk_end']}"
    result[:worker_id] = WORKER_ID
    publisher.publish(RESULT_CHANNEL, result.to_json)

    lock.synchronize do
      idle = true
    end
  end
end
