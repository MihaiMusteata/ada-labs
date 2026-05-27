using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using StackExchange.Redis;

const string TaskStream = "puzzle:tasks";
const string ResultStream = "puzzle:results";
const string GroupName = "workers";
const string CancelKey = "puzzle:cancelled";
const string WinnerKey = "puzzle:winner";
const string WorkerName = "C# worker";
const long CheckInterval = 10_000;

var consumerName = $"csharp-{Environment.ProcessId}";
var jsonOptions = new JsonSerializerOptions
{
    PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
};

var redis = ConnectionMultiplexer.Connect("redis:6379");
var db = redis.GetDatabase();

Console.WriteLine("C# Redis Streams worker started...");
Console.WriteLine($"Listening stream: {TaskStream}, group={GroupName}, consumer={consumerName}");

while (true)
{
    StreamEntry[] entries;

    try
    {
        entries = db.StreamReadGroup(TaskStream, GroupName, consumerName, ">", count: 1);
    }
    catch (RedisServerException ex) when (ex.Message.Contains("NOGROUP"))
    {
        Thread.Sleep(1000);
        continue;
    }

    if (entries.Length == 0)
    {
        Thread.Sleep(250);
        continue;
    }

    StreamEntry entry = entries[0];
    string payload = entry.Values.First(value => value.Name == "payload").Value.ToString();
    ChunkTask task = JsonSerializer.Deserialize<ChunkTask>(payload, jsonOptions)!;

    Console.WriteLine($"Received chunk: {task.ChunkStart}..{task.ChunkEnd}, difficulty={task.Difficulty}");
    ChunkResult result = SolveChunk(task, db);

    if (result.Status == "cancelled")
    {
        Console.WriteLine($"Searching was stopped..... found by another worker ({result.Winner ?? "another worker"})");
        db.StreamAcknowledge(TaskStream, GroupName, entry.Id);
        continue;
    }

    Console.WriteLine($"Chunk result by {WorkerName}: {result.Status}, chunk={task.ChunkStart}..{task.ChunkEnd}");
    db.StreamAdd(ResultStream, new NameValueEntry[]
    {
        new("payload", JsonSerializer.Serialize(result, jsonOptions))
    });
    db.StreamAcknowledge(TaskStream, GroupName, entry.Id);
}

ChunkResult SolveChunk(ChunkTask task, IDatabase db)
{
    string needle = new('0', task.Difficulty);
    long checks = 0;

    for (long n = task.ChunkStart; n <= task.ChunkEnd; n++)
    {
        if (checks % CheckInterval == 0 && db.StringGet(CancelKey) == "1")
        {
            return new ChunkResult
            {
                Status = "cancelled",
                Worker = WorkerName,
                Winner = db.StringGet(WinnerKey).ToString()
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
    public string? Winner { get; set; }
    public long ChunkStart { get; set; }
    public long ChunkEnd { get; set; }
}
