using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using StackExchange.Redis;

const string TasksQueue = "puzzle:tasks";
const string ResultsQueue = "puzzle:results";
const string CancelKey = "puzzle:cancelled";
const string WinnerKey = "puzzle:winner";
const string WorkerName = "C# worker";
const long CheckInterval = 10_000;

var jsonOptions = new JsonSerializerOptions
{
    PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
};

var redis = ConnectionMultiplexer.Connect("redis:6379");
var db = redis.GetDatabase();

Console.WriteLine("C# Redis Lists worker started...");
Console.WriteLine($"Listening queue: {TasksQueue}");

while (true)
{
    RedisValue payload = db.ListLeftPop(TasksQueue);

    if (payload.IsNullOrEmpty)
    {
        Thread.Sleep(250);
        continue;
    }

    ChunkTask task = JsonSerializer.Deserialize<ChunkTask>(payload.ToString(), jsonOptions)!;
    Console.WriteLine($"Received chunk: {task.ChunkStart}..{task.ChunkEnd}, difficulty={task.Difficulty}");

    ChunkResult result = SolveChunk(task, db);

    if (result.Status == "cancelled")
    {
        Console.WriteLine($"Searching was stopped..... found by another worker ({result.Winner ?? "another worker"})");
        continue;
    }

    Console.WriteLine($"Chunk result by {WorkerName}: {result.Status}, chunk={task.ChunkStart}..{task.ChunkEnd}");
    db.ListRightPush(ResultsQueue, JsonSerializer.Serialize(result, jsonOptions));
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
