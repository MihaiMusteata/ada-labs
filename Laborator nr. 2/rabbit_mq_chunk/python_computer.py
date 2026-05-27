import hashlib
import json
import threading

import pika

USER = "guest"
PASSWORD = "guest"
HOST = "rabbitmq"
PORT = 5672
QUEUE_NAME = "crypto-puzzle-chunks"
CANCEL_EXCHANGE_NAME = "crypto-puzzle-cancel"
WORKER_NAME = "Python worker"
CHECK_INTERVAL = 10000

state_lock = threading.Lock()
current_correlation_id = None
cancel_event = threading.Event()
cancel_winner = None


def solve_chunk(string, difficulty, chunk_start, chunk_end):
    needle = "0" * difficulty
    checks = 0

    for n in range(chunk_start, chunk_end + 1):
        if checks % CHECK_INTERVAL == 0 and cancel_event.is_set():
            return {
                "status": "cancelled",
                "worker": WORKER_NAME,
                "chunk_start": chunk_start,
                "chunk_end": chunk_end
            }

        solution_candidate = string + str(n)
        result_hash = hashlib.sha256(solution_candidate.encode("utf-8")).hexdigest()

        if result_hash[:difficulty] == needle:
            return {
                "status": "found",
                "solution": solution_candidate,
                "nonce": n,
                "hash": result_hash,
                "worker": WORKER_NAME,
                "chunk_start": chunk_start,
                "chunk_end": chunk_end
            }

        checks += 1

    return {
        "status": "not_found",
        "worker": WORKER_NAME,
        "chunk_start": chunk_start,
        "chunk_end": chunk_end
    }


def listen_for_cancel_messages(credentials):
    global cancel_winner

    cancel_connection = pika.BlockingConnection(
        pika.ConnectionParameters(host=HOST, port=PORT, credentials=credentials)
    )
    cancel_channel = cancel_connection.channel()
    cancel_channel.exchange_declare(
        exchange=CANCEL_EXCHANGE_NAME,
        exchange_type="fanout"
    )

    result = cancel_channel.queue_declare(queue="", exclusive=True, auto_delete=True)
    cancel_queue_name = result.method.queue
    cancel_channel.queue_bind(
        exchange=CANCEL_EXCHANGE_NAME,
        queue=cancel_queue_name
    )

    def cancel_callback(_channel, _method, _properties, body):
        global cancel_winner

        message = json.loads(body)

        with state_lock:
            if message.get("correlation_id") != current_correlation_id:
                return

            if message.get("winner") == WORKER_NAME:
                return

            cancel_winner = message.get("winner", "another worker")
            cancel_event.set()

    cancel_channel.basic_consume(
        queue=cancel_queue_name,
        on_message_callback=cancel_callback,
        auto_ack=True
    )
    cancel_channel.start_consuming()


def callback(channel, method, properties, body):
    global current_correlation_id
    global cancel_winner

    json_payload = json.loads(body)

    string = json_payload["string"]
    difficulty = json_payload["difficulty"]
    chunk_start = json_payload["chunk_start"]
    chunk_end = json_payload["chunk_end"]

    with state_lock:
        current_correlation_id = properties.correlation_id
        cancel_winner = None
        cancel_event.clear()

    print(f"Received chunk: {chunk_start}..{chunk_end}, difficulty={difficulty}")

    result = solve_chunk(string, difficulty, chunk_start, chunk_end)

    if result["status"] == "cancelled":
        with state_lock:
            stopped_by = cancel_winner or "another worker"

        print(f"Searching was stopped..... found by another worker ({stopped_by})")
        channel.basic_ack(delivery_tag=method.delivery_tag)
        return

    print(
        f"Chunk result by {WORKER_NAME}: "
        f"{result['status']}, chunk={chunk_start}..{chunk_end}"
    )

    channel.basic_publish(
        exchange="",
        routing_key=properties.reply_to,
        properties=pika.BasicProperties(correlation_id=properties.correlation_id),
        body=json.dumps(result)
    )

    channel.basic_ack(delivery_tag=method.delivery_tag)


credentials = pika.PlainCredentials(USER, PASSWORD)
connection = pika.BlockingConnection(
    pika.ConnectionParameters(host=HOST, port=PORT, credentials=credentials)
)

channel = connection.channel()
channel.queue_declare(queue=QUEUE_NAME, auto_delete=True)
channel.basic_qos(prefetch_count=1)

threading.Thread(
    target=listen_for_cancel_messages,
    args=(credentials,),
    daemon=True
).start()

print("Python chunk worker started...")
print(f"Listening queue: {QUEUE_NAME}")

channel.basic_consume(
    queue=QUEUE_NAME,
    on_message_callback=callback,
    auto_ack=False
)

try:
    channel.start_consuming()
except KeyboardInterrupt:
    print("Stopping Python chunk worker...")
    channel.stop_consuming()
    connection.close()
