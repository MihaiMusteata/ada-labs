# frozen_string_literal: true

require 'bunny'
require 'digest/sha2'
require 'json'

user = 'guest'
password = 'guest'
host = 'rabbitmq'
port = 5672
queue_name = 'crypto-puzzle-inquiries'

def solve_crypto_puzzle(string, difficulty, start, step)
  sha256 = Digest::SHA256.new
  needle = '0' * difficulty
  n = start

  loop do
    solution_candidate = string + n.to_s
    result = sha256.hexdigest(solution_candidate)

    if result[0...difficulty] == needle
      return {
        solution: solution_candidate,
        nonce: n,
        hash: result,
        worker: 'Ruby worker'
      }
    end

    n += step
  end
end

connection = Bunny.new(hostname: host, port: port, username: user, password: password)
connection.start

channel = connection.create_channel
exchange = channel.default_exchange

queue = channel.queue(queue_name, auto_delete: true)

begin
  puts 'Ruby worker started...'
  puts "Listening queue: #{queue_name}"

  queue.subscribe(block: true) do |_delivery_info, properties, payload|
    json_payload = JSON.parse(payload)

    string = json_payload['string']
    difficulty = json_payload['difficulty']
    start = json_payload['start'] || 0
    step = json_payload['step'] || 1

    puts "Received task: string=#{string}, difficulty=#{difficulty}, start=#{start}, step=#{step}"

    result = solve_crypto_puzzle(string, difficulty, start, step)

    puts "Solution found by Ruby worker: nonce=#{result[:nonce]}, hash=#{result[:hash]}"

    exchange.publish(
      result.to_json,
      routing_key: properties.reply_to,
      correlation_id: properties.correlation_id
    )
  end
rescue Interrupt => _e
  channel.close
  connection.close
  exit(0)
end
