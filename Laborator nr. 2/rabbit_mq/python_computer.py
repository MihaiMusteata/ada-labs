import json
import hashlib
import pika

USER = "guest"
PASSWORD = "guest"
HOST = "rabbitmq"
PORT = 5672
QUEUE_NAME = "crypto-puzzle-inquiries"


def solve_crypto_puzzle(string, difficulty, start, step):
    needle = "0" * difficulty
    n = start

    while True:
        solution_candidate = string + str(n)
        result_hash = hashlib.sha256(solution_candidate.encode("utf-8")).hexdigest()

        if result_hash[:difficulty] == needle:
            return {
                "solution": solution_candidate,
                "nonce": n,
                "hash": result_hash,
                "worker": "Python worker"
            }

        n += step


def callback(channel, method, properties, body):
    json_payload = json.loads(body)

    string = json_payload["string"]
    difficulty = json_payload["difficulty"]
    start = json_payload.get("start", 0)
    step = json_payload.get("step", 1)

    print(
        f"Received task: string={string}, "
        f"difficulty={difficulty}, start={start}, step={step}"
    )

    result = solve_crypto_puzzle(string, difficulty, start, step)

    print(
        f"Solution found by Python worker: "
        f"nonce={result['nonce']}, hash={result['hash']}"
    )

    channel.basic_publish(
        exchange="",
        routing_key=properties.reply_to,
        properties=pika.BasicProperties(
            correlation_id=properties.correlation_id
        ),
        body=json.dumps(result)
    )


credentials = pika.PlainCredentials(USER, PASSWORD)

connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host=HOST,
        port=PORT,
        credentials=credentials
    )
)

channel = connection.channel()

channel.queue_declare(
    queue=QUEUE_NAME,
    auto_delete=True
)

print("Python worker started...")
print(f"Listening queue: {QUEUE_NAME}")

channel.basic_consume(
    queue=QUEUE_NAME,
    on_message_callback=callback,
    auto_ack=True
)

try:
    channel.start_consuming()
except KeyboardInterrupt:
    print("Stopping Python worker...")
    channel.stop_consuming()
    connection.close()