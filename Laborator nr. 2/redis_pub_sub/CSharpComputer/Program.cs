using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using StackExchange.Redis;

const string RequestChannel = "puzzle:requests";
const string ResultChannel = "puzzle:results";
const string CancelChannel = "puzzle:cancel";
const string TaskChannelPrefix = "puzzle:tasks";
const string WorkerName = "C# worker";
const long CheckInterval = 10_000;

var workerId = $"csharp-{Environment.ProcessId}";
var taskChannel = $"{TaskChannelPrefix}:{workerId}";
var stateLock = new object();
var idle = true;
var cancelled = false;
string? winner = null;

var jsonOptions = new JsonSerializerOptions
{
    PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
};

var redis = ConnectionMultiplexer.Connect("redis:6379");
var subscriber = redis.GetSubscriber();

subscriber.Subscribe(RedisChannel.Literal(CancelChannel), (_, message) =>
{
    JsonElement payload = JsonSerializer.Deserialize<JsonElement>(message.ToString());

    lock (stateLock)
    {
        cancelled = true;
        winner = payload.GetProperty("winner").GetString();
    }
});

subscriber.Subscribe(RedisChannel.Literal(taskChannel), (_, message) =>
{
    lock (stateLock)
    {
        idle = false;
        cancelled = false;
        winner = null;
    }

    ChunkTask task = JsonSerializer.Deserialize<ChunkTask>(message.ToString(), jsonOptions)!;
    Console.WriteLine($"Received chunk: {task.ChunkStart}..{task.ChunkEnd}, difficulty={task.Difficulty}");

    ChunkResult result = SolveChunk(task);

    if (result.Status == "cancelled")
    {
        string stoppedBy;

        lock (stateLock)
        {
            stoppedBy = winner ?? "another worker";
        }

        Console.WriteLine($"Searching was stopped..... found by another worker ({stoppedBy})");
        lock (stateLock)
        {
            idle = true;
        }
        return;
    }

    Console.WriteLine($"Chunk result by {WorkerName}: {result.Status}, chunk={task.ChunkStart}..{task.ChunkEnd}");
    result.WorkerId = workerId;
    subscriber.Publish(RedisChannel.Literal(ResultChannel), JsonSerializer.Serialize(result, jsonOptions));

    lock (stateLock)
    {
        idle = true;
    }
});

Console.WriteLine("C# Redis Pub/Sub worker started...");
Console.WriteLine($"Listening channel: {taskChannel}");

while (true)
{
    bool shouldRequest;

    lock (stateLock)
    {
        shouldRequest = idle;
    }

    if (shouldRequest)
    {
        subscriber.Publish(
            RedisChannel.Literal(RequestChannel),
            JsonSerializer.Serialize(new
            {
                worker_id = workerId,
                worker = WorkerName
            })
        );
    }

    Thread.Sleep(1000);
}

ChunkResult SolveChunk(ChunkTask task)
{
    string needle = new('0', task.Difficulty);
    long checks = 0;

    for (long n = task.ChunkStart; n <= task.ChunkEnd; n++)
    {
        bool shouldCancel;

        lock (stateLock)
        {
            shouldCancel = cancelled;
        }

        if (checks % CheckInterval == 0 && shouldCancel)
        {
            return new ChunkResult
            {
                Status = "cancelled",
                Worker = WorkerName
            };
        }

        string solutionCandidate = task.String + n;
        byte[] bytes = Encoding.UTF8.GetBytes(solutionCandidate);
        byte[] hashBytes = SHA256.HashData(bytes);
        string hash = Convert.ToHexString(hashBytes).ToLowerInvariant();

        if (hash.StartsWith(needle))
        {
            return new ChunkResult
            {
                Status = "found",
                Solution = solutionCandidate,
                Nonce = n,
                Hash = hash,
                Worker = WorkerName,
                ChunkStart = task.ChunkStart,
                ChunkEnd = task.ChunkEnd
            };
        }

        checks++;
    }

    return new ChunkResult
    {
        Status = "not_found",
        Worker = WorkerName,
        ChunkStart = task.ChunkStart,
        ChunkEnd = task.ChunkEnd
    };
}

internal sealed class ChunkTask
{
    public string String { get; set; } = "";
    public int Difficulty { get; set; }
    public long ChunkStart { get; set; }
    public long ChunkEnd { get; set; }
}

internal sealed class ChunkResult
{
    public string Status { get; set; } = "";
    public string? Solution { get; set; }
    public long? Nonce { get; set; }
    public string? Hash { get; set; }
    public string Worker { get; set; } = "";
    public string? WorkerId { get; set; }
    public long ChunkStart { get; set; }
    public long ChunkEnd { get; set; }
}
