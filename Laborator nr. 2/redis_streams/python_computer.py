import hashlib
import json
import os
import time

import redis

HOST = "redis"
PORT = 6379
TASK_STREAM = "puzzle:tasks"
RESULT_STREAM = "puzzle:results"
GROUP_NAME = "workers"
CANCEL_KEY = "puzzle:cancelled"
WINNER_KEY = "puzzle:winner"
WORKER_NAME = "Python worker"
CONSUMER_NAME = f"python-{os.getpid()}"
CHECK_INTERVAL = 10000


def solve_chunk(client, task):
    needle = "0" * task["difficulty"]
    checks = 0

    for n in range(task["chunk_start"], task["chunk_end"] + 1):
        if checks % CHECK_INTERVAL == 0 and client.get(CANCEL_KEY) == "1":
            return {
                "status": "cancelled",
                "worker": WORKER_NAME,
                "winner": client.get(WINNER_KEY)
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


client = redis.Redis(host=HOST, port=PORT, decode_responses=True)

print("Python Redis Streams worker started...")
print(f"Listening stream: {TASK_STREAM}, group={GROUP_NAME}, consumer={CONSUMER_NAME}")

while True:
    try:
        response = client.xreadgroup(
            groupname=GROUP_NAME,
            consumername=CONSUMER_NAME,
            streams={TASK_STREAM: ">"},
            count=1,
            block=1000
        )
    except redis.exceptions.ResponseError as exc:
        if "NOGROUP" not in str(exc):
            raise
        time.sleep(1)
        continue

    if not response:
        continue

    _, entries = response[0]
    entry_id, fields = entries[0]
    task = json.loads(fields["payload"])

    print(f"Received chunk: {task['chunk_start']}..{task['chunk_end']}, difficulty={task['difficulty']}")
    result = solve_chunk(client, task)

    if result["status"] == "cancelled":
        print(f"Searching was stopped..... found by another worker ({result.get('winner') or 'another worker'})")
        client.xack(TASK_STREAM, GROUP_NAME, entry_id)
        continue

    print(f"Chunk result by {WORKER_NAME}: {result['status']}, chunk={task['chunk_start']}..{task['chunk_end']}")
    client.xadd(RESULT_STREAM, {"payload": json.dumps(result)})
    client.xack(TASK_STREAM, GROUP_NAME, entry_id)
