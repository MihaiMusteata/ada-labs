using System.Text;
using System.Text.Json;
using System.Security.Cryptography;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

const string User = "guest";
const string Password = "guest";
const string Host = "rabbitmq";
const int Port = 5672;
const string QueueName = "crypto-puzzle-inquiries";

static object SolveCryptoPuzzle(string input, int difficulty, long start, long step)
{
    string needle = new string('0', difficulty);
    long n = start;

    while (true)
    {
        string solutionCandidate = input + n;
        byte[] bytes = Encoding.UTF8.GetBytes(solutionCandidate);
        byte[] hashBytes = SHA256.HashData(bytes);

        string hash = Convert.ToHexString(hashBytes).ToLowerInvariant();

        if (hash.StartsWith(needle))
        {
            return new
            {
                solution = solutionCandidate,
                nonce = n,
                hash = hash,
                worker = "C# worker"
            };
        }

        n += step;
    }
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

channel.QueueDeclare(
    queue: QueueName,
    durable: false,
    exclusive: false,
    autoDelete: true,
    arguments: null
);

Console.WriteLine("C# worker started...");
Console.WriteLine($"Listening queue: {QueueName}");

var consumer = new EventingBasicConsumer(channel);

consumer.Received += (model, ea) =>
{
    string body = Encoding.UTF8.GetString(ea.Body.ToArray());
    JsonElement jsonPayload = JsonSerializer.Deserialize<JsonElement>(body);

    string input = jsonPayload.GetProperty("string").GetString()!;
    int difficulty = jsonPayload.GetProperty("difficulty").GetInt32();

    long start = jsonPayload.TryGetProperty("start", out JsonElement startElement)
        ? startElement.GetInt64()
        : 0;

    long step = jsonPayload.TryGetProperty("step", out JsonElement stepElement)
        ? stepElement.GetInt64()
        : 1;

    Console.WriteLine(
        $"Received task: string={input}, difficulty={difficulty}, start={start}, step={step}"
    );

    object result = SolveCryptoPuzzle(input, difficulty, start, step);
    string response = JsonSerializer.Serialize(result);
    byte[] responseBytes = Encoding.UTF8.GetBytes(response);

    Console.WriteLine($"Solution found by C# worker: {response}");

    var replyProperties = channel.CreateBasicProperties();
    replyProperties.CorrelationId = ea.BasicProperties.CorrelationId;

    channel.BasicPublish(
        exchange: "",
        routingKey: ea.BasicProperties.ReplyTo,
        basicProperties: replyProperties,
        body: responseBytes
    );
};

channel.BasicConsume(
    queue: QueueName,
    autoAck: true,
    consumer: consumer
);

Console.WriteLine("Press Enter to stop C# worker.");
Console.ReadLine();