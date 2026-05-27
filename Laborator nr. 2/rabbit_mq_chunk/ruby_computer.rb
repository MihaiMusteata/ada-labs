# frozen_string_literal: true

require 'bunny'
require 'digest/sha2'
require 'json'

USER = 'guest'
PASSWORD = 'guest'
HOST = 'rabbitmq'
PORT = 5672
QUEUE_NAME = 'crypto-puzzle-chunks'
CANCEL_EXCHANGE_NAME = 'crypto-puzzle-cancel'
WORKER_NAME = 'Ruby worker'
CHECK_INTERVAL = 10_000

def solve_chunk(string, difficulty, chunk_start, chunk_end, cancelled)
  sha256 = Digest::SHA256.new
  needle = '0' * difficulty
  checks = 0

  (chunk_start..chunk_end).each do |n|
    if (checks % CHECK_INTERVAL).zero? && cancelled.call
      return {
        status: 'cancelled',
        worker: WORKER_NAME,
        chunk_start: chunk_start,
        chunk_end: chunk_end
      }
    end

    solution_candidate = string + n.to_s
    result = sha256.hexdigest(solution_candidate)

    if result[0...difficulty] == needle
      return {
        status: 'found',
        solution: solution_candidate,
        nonce: n,
        hash: result,
        worker: WORKER_NAME,
        chunk_start: chunk_start,
        chunk_end: chunk_end
      }
    end

    checks += 1
  end

  {
    status: 'not_found',
    worker: WORKER_NAME,
    chunk_start: chunk_start,
    chunk_end: chunk_end
  }
end

connection = Bunny.new(hostname: HOST, port: PORT, username: USER, password: PASSWORD)
connection.start
cancel_connection = Bunny.new(hostname: HOST, port: PORT, username: USER, password: PASSWORD)
cancel_connection.start

channel = connection.create_channel
channel.prefetch(1)
exchange = channel.default_exchange
queue = channel.queue(QUEUE_NAME, auto_delete: true)

cancel_channel = cancel_connection.create_channel
cancel_exchange = cancel_channel.fanout(CANCEL_EXCHANGE_NAME)
cancel_queue = cancel_channel.queue('', exclusive: true, auto_delete: true)
cancel_queue.bind(cancel_exchange)

state_lock = Mutex.new
current_correlation_id = nil
cancelled = false
winner = nil

cancel_queue.subscribe do |_delivery_info, _properties, payload|
  message = JSON.parse(payload)

  state_lock.synchronize do
    next unless message['correlation_id'] == current_correlation_id
    next if message['winner'] == WORKER_NAME

    cancelled = true
    winner = message['winner']
  end
end

begin
  puts 'Ruby chunk worker started...'
  puts "Listening queue: #{QUEUE_NAME}"

  queue.subscribe(block: true, manual_ack: true) do |delivery_info, properties, payload|
    json_payload = JSON.parse(payload)

    string = json_payload['string']
    difficulty = json_payload['difficulty']
    chunk_start = json_payload['chunk_start']
    chunk_end = json_payload['chunk_end']

    state_lock.synchronize do
      current_correlation_id = properties.correlation_id
      cancelled = false
      winner = nil
    end

    puts "Received chunk: #{chunk_start}..#{chunk_end}, difficulty=#{difficulty}"

    result = solve_chunk(string, difficulty, chunk_start, chunk_end, lambda {
      state_lock.synchronize { cancelled }
    })

    if result[:status] == 'cancelled'
      stopped_by = state_lock.synchronize { winner || 'another worker' }
      puts "Searching was stopped..... found by another worker (#{stopped_by})"
      channel.ack(delivery_info.delivery_tag)
      next
    end

    puts "Chunk result by #{WORKER_NAME}: #{result[:status]}, chunk=#{chunk_start}..#{chunk_end}"

    exchange.publish(
      result.to_json,
      routing_key: properties.reply_to,
      correlation_id: properties.correlation_id
    )

    channel.ack(delivery_info.delivery_tag)
  end
rescue Interrupt => _e
  channel.close
  connection.close
  cancel_channel.close
  cancel_connection.close
  exit(0)
end
