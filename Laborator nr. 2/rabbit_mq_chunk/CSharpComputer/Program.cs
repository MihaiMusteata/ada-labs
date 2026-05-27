using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

const string User = "guest";
const string Password = "guest";
const string Host = "rabbitmq";
const int Port = 5672;
const string QueueName = "crypto-puzzle-chunks";
const string CancelExchangeName = "crypto-puzzle-cancel";
const string WorkerName = "C# worker";
const long CheckInterval = 10_000;

object stateLock = new();
string? currentCorrelationId = null;
string? cancelWinner = null;
bool cancelRequested = false;

var jsonOptions = new JsonSerializerOptions
{
    PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
};

ChunkResult SolveChunk(string input, int difficulty, long chunkStart, long chunkEnd)
{
    string needle = new('0', difficulty);
    long checks = 0;

    for (long n = chunkStart; n <= chunkEnd; n++)
    {
        if (checks % CheckInterval == 0)
        {
            lock (stateLock)
            {
                if (cancelRequested)
                {
                    return new ChunkResult
                    {
                        Status = "cancelled",
                        Worker = WorkerName,
                        ChunkStart = chunkStart,
                        ChunkEnd = chunkEnd
                    };
                }
            }
        }

        string solutionCandidate = input + n;
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
                ChunkStart = chunkStart,
                ChunkEnd = chunkEnd
            };
        }

        checks++;
    }

    return new ChunkResult
    {
        Status = "not_found",
        Worker = WorkerName,
        ChunkStart = chunkStart,
        ChunkEnd = chunkEnd
    };
}

var factory = new ConnectionFactory
{
    HostName = Host,
    Port = Port,
    UserName = User,
    Password = Password
};

using var connection = factory.CreateConnection();
using var channel = connection.CreateModel();
using var cancelConnection = factory.CreateConnection();
using var cancelChannel = cancelConnection.CreateModel();

channel.QueueDeclare(
    queue: QueueName,
    durable: false,
    exclusive: false,
    autoDelete: true,
    arguments: null
);

channel.BasicQos(
    prefetchSize: 0,
    prefetchCount: 1,
    global: false
);

cancelChannel.ExchangeDeclare(
    exchange: CancelExchangeName,
    type: ExchangeType.Fanout
);

string cancelQueueName = cancelChannel.QueueDeclare(
    queue: "",
    durable: false,
    exclusive: true,
    autoDelete: true,
    arguments: null
).QueueName;

cancelChannel.QueueBind(
    queue: cancelQueueName,
    exchange: CancelExchangeName,
    routingKey: ""
);

var cancelConsumer = new EventingBasicConsumer(cancelChannel);

cancelConsumer.Received += (model, ea) =>
{
    string body = Encoding.UTF8.GetString(ea.Body.ToArray());
    JsonElement message = JsonSerializer.Deserialize<JsonElement>(body);

    string? correlationId = message.GetProperty("correlation_id").GetString();
    string? winner = message.GetProperty("winner").GetString();

    lock (stateLock)
    {
        if (correlationId != currentCorrelationId || winner == WorkerName)
        {
            return;
        }

        cancelWinner = winner ?? "another worker";
        cancelRequested = true;
    }
};

cancelChannel.BasicConsume(
    queue: cancelQueueName,
    autoAck: true,
    consumer: cancelConsumer
);

Console.WriteLine("C# chunk worker started...");
Console.WriteLine($"Listening queue: {QueueName}");

var consumer = new EventingBasicConsumer(channel);

consumer.Received += (model, ea) =>
{
    string body = Encoding.UTF8.GetString(ea.Body.ToArray());
    JsonElement jsonPayload = JsonSerializer.Deserialize<JsonElement>(body);

    string input = jsonPayload.GetProperty("string").GetString()!;
    int difficulty = jsonPayload.GetProperty("difficulty").GetInt32();
    long chunkStart = jsonPayload.GetProperty("chunk_start").GetInt64();
    long chunkEnd = jsonPayload.GetProperty("chunk_end").GetInt64();

    lock (stateLock)
    {
        currentCorrelationId = ea.BasicProperties.CorrelationId;
        cancelWinner = null;
        cancelRequested = false;
    }

    Console.WriteLine($"Received chunk: {chunkStart}..{chunkEnd}, difficulty={difficulty}");

    ChunkResult result = SolveChunk(input, difficulty, chunkStart, chunkEnd);

    if (result.Status == "cancelled")
    {
        string stoppedBy;

        lock (stateLock)
        {
            stoppedBy = cancelWinner ?? "another worker";
        }

        Console.WriteLine($"Searching was stopped..... found by another worker ({stoppedBy})");

        channel.BasicAck(
            deliveryTag: ea.DeliveryTag,
            multiple: false
        );

        return;
    }

    Console.WriteLine($"Chunk result by {WorkerName}: {result.Status}, chunk={chunkStart}..{chunkEnd}");

    string response = JsonSerializer.Serialize(result, jsonOptions);
    byte[] responseBytes = Encoding.UTF8.GetBytes(response);

    var replyProperties = channel.CreateBasicProperties();
    replyProperties.CorrelationId = ea.BasicProperties.CorrelationId;

    channel.BasicPublish(
        exchange: "",
        routingKey: ea.BasicProperties.ReplyTo,
        basicProperties: replyProperties,
        body: responseBytes
    );

    channel.BasicAck(
        deliveryTag: ea.DeliveryTag,
        multiple: false
    );
};

channel.BasicConsume(
    queue: QueueName,
    autoAck: false,
    consumer: consumer
);

Console.WriteLine("Press Enter to stop C# chunk worker.");
Console.ReadLine();

internal sealed class ChunkResult
{
    public string Status { get; set; } = "";
    public string? Solution { get; set; }
    public long? Nonce { get; set; }
    public string? Hash { get; set; }
    public string Worker { get; set; } = "";
    public long ChunkStart { get; set; }
    public long ChunkEnd { get; set; }
}
