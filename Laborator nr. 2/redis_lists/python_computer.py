import hashlib
import json
import redis

HOST = "redis"
PORT = 6379
TASKS_QUEUE = "puzzle:tasks"
RESULTS_QUEUE = "puzzle:results"
CANCEL_KEY = "puzzle:cancelled"
WINNER_KEY = "puzzle:winner"
WORKER_NAME = "Python worker"
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

print("Python Redis Lists worker started...")
print(f"Listening queue: {TASKS_QUEUE}")

while True:
    item = client.blpop(TASKS_QUEUE, timeout=1)
    if item is None:
        continue

    _, payload = item
    task = json.loads(payload)
    print(f"Received chunk: {task['chunk_start']}..{task['chunk_end']}, difficulty={task['difficulty']}")

    result = solve_chunk(client, task)

    if result["status"] == "cancelled":
        print(f"Searching was stopped..... found by another worker ({result.get('winner') or 'another worker'})")
        continue

    print(f"Chunk result by {WORKER_NAME}: {result['status']}, chunk={task['chunk_start']}..{task['chunk_end']}")
    client.rpush(RESULTS_QUEUE, json.dumps(result))
