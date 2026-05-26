# Laborator #2 TI - RabbitMQ, Ruby, Python, C#

Proiectul ruleaza un sistem distribuit local prin Docker Compose:

- `rabbitmq` - broker RabbitMQ cu management UI;
- `lab2_producer` - container pentru serverul/producerul Ruby;
- `lab2_ruby_consumer` - container pentru workerul Ruby;
- `lab2_python_consumer` - container pentru workerul Python;
- `lab2_csharp_consumer` - container pentru workerul C#.

Toate serviciile sunt in reteaua Docker `main`. Din containere, RabbitMQ se acceseaza cu hostul `rabbitmq`, portul `5672`, user `guest`, parola `guest`.

## Pornire containere

```bash
docker compose down
docker compose build
docker compose up -d
docker compose ps
```

Management UI RabbitMQ este disponibil pe:

```text
http://localhost:15672
```

Credentiale:

```text
guest / guest
```

## Rulare workeri

Porneste fiecare worker intr-un terminal separat.

Ruby worker:

```bash
docker exec -it lab2_ruby_consumer ruby ruby_computer.rb
```

Python worker:

```bash
docker exec -it lab2_python_consumer python3 python_computer.py
```

C# worker:

```bash
docker exec -it lab2_csharp_consumer dotnet run --project CSharpComputer/CSharpComputer.csproj
```

## Rulare producer Ruby

Intr-un alt terminal:

```bash
docker exec -it lab2_producer ruby ruby_server.rb
```

Producerul trimite 3 taskuri pentru aceeasi problema, cu `start` egal cu `0`, `1`, `2` si `step` egal cu `3`. Workerii cauta solutia pe intervale diferite si primul raspuns primit este afisat impreuna cu timpul in milisecunde.

## Oprire

```bash
docker compose down
```

## Probleme cu permisiunile RabbitMQ

Daca serviciul `rabbitmq` se opreste imediat si in `docker compose ps` apare cu status `Exit 0`, pot exista permisiuni incorecte pentru datele persistente. Incearca:

```bash
sudo chmod -R 777 rabbitmq-data/log rabbitmq-data/data
docker compose up -d
```
