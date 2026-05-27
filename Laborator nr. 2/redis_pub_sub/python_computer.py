import hashlib
import json
import os
import threading
import time

import redis

HOST = "redis"
PORT = 6379
REQUEST_CHANNEL = "puzzle:requests"
RESULT_CHANNEL = "puzzle:results"
CANCEL_CHANNEL = "puzzle:cancel"
TASK_CHANNEL_PREFIX = "puzzle:tasks"
WORKER_NAME = "Python worker"
WORKER_ID = f"python-{os.getpid()}"
CHECK_INTERVAL = 10000

lock = threading.Lock()
idle = True
cancelled = False
winner = None


def solve_chunk(task):
    needle = "0" * task["difficulty"]
    checks = 0

    for n in range(task["chunk_start"], task["chunk_end"] + 1):
        with lock:
            should_cancel = cancelled

        if checks % CHECK_INTERVAL == 0 and should_cancel:
            return {
                "status": "cancelled",
                "worker": WORKER_NAME
            }

        solution_candidate = task["string"] + str(n)
        result_hash = hashlib.sha256(solution_candidate.encode("utf-8")).hexdigest()

        if result_hash[:task["difficulty"]] == needle:
            return {
                "status": "found",
                "solution": solution_candidate,
                "nonce": n,
                "hash": result_hash,
                "worker": WORKER_NAME,
                "chunk_start": task["chunk_start"],
                "chunk_end": task["chunk_end"]
            }

        checks += 1

    return {
        "status": "not_found",
        "worker": WORKER_NAME,
        "chunk_start": task["chunk_start"],
        "chunk_end": task["chunk_end"]
    }


publisher = redis.Redis(host=HOST, port=PORT, decode_responses=True)


def request_loop():
    while True:
        with lock:
            should_request = idle

        if should_request:
            publisher.publish(
                REQUEST_CHANNEL,
                json.dumps({
                    "worker_id": WORKER_ID,
                    "worker": WORKER_NAME
                })
            )

        time.sleep(1)


def cancel_loop():
    global cancelled
    global winner

    subscriber = redis.Redis(host=HOST, port=PORT, decode_responses=True)
    pubsub = subscriber.pubsub()
    pubsub.subscribe(CANCEL_CHANNEL)

    for message in pubsub.listen():
        if message["type"] != "message":
            continue

        payload = json.loads(message["data"])

        with lock:
            cancelled = True
            winner = payload.get("winner")


def task_loop():
    global idle
    global cancelled
    global winner

    subscriber = redis.Redis(host=HOST, port=PORT, decode_responses=True)
    pubsub = subscriber.pubsub()
    pubsub.subscribe(f"{TASK_CHANNEL_PREFIX}:{WORKER_ID}")

    print("Python Redis Pub/Sub worker started...")
    print(f"Listening channel: {TASK_CHANNEL_PREFIX}:{WORKER_ID}")

    for message in pubsub.listen():
        if message["type"] != "message":
            continue

        with lock:
            idle = False
            cancelled = False
            winner = None

        task = json.loads(message["data"])
        print(f"Received chunk: {task['chunk_start']}..{task['chunk_end']}, difficulty={task['difficulty']}")

        result = solve_chunk(task)

        if result["status"] == "cancelled":
            with lock:
                stopped_by = winner or "another worker"
                idle = True
            print(f"Searching was stopped..... found by another worker ({stopped_by})")
            continue

        print(f"Chunk result by {WORKER_NAME}: {result['status']}, chunk={task['chunk_start']}..{task['chunk_end']}")
        result["worker_id"] = WORKER_ID
        publisher.publish(RESULT_CHANNEL, json.dumps(result))

        with lock:
            idle = True


threading.Thread(target=request_loop, daemon=True).start()
threading.Thread(target=cancel_loop, daemon=True).start()
task_loop()
