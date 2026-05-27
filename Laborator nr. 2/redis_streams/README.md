# Redis Streams cu chunkuri

Aceasta este varianta Redis Streams în care serverul împarte spațiul de căutare în intervale finite de nonce-uri. Workerii Ruby, Python și C# citesc din același consumer group, astfel încât fiecare chunk este primit de un singur worker.

## Distribuire taskuri

Serverul trimite chunkuri în streamul `puzzle:tasks`, iar workerii citesc din consumer group-ul `workers`.

Exemplu:

```text
chunk 1: 0..499999
chunk 2: 500000..999999
chunk 3: 1000000..1499999
```

Workerii trimit rezultatele în streamul `puzzle:results`. Dacă un worker termină un chunk și nu găsește soluția, trimite `not_found`, confirmă taskul cu `XACK`, iar serverul trimite următorul chunk. Dacă un worker găsește soluția, trimite `found`, serverul afișează rezultatul și setează cheia `puzzle:cancelled`.

Serverul nu trimite toate chunkurile deodată. El menține o fereastră limitată:

```text
WINDOW_SIZE = WORKERS_COUNT * 2
```

Pentru 3 workeri, în sistem sunt cel mult 6 chunkuri active. Redis este expus local pe portul `6381`.

## Pornire

```bash
chmod +x start_cluster.sh stop_cluster.sh
./start_cluster.sh
docker compose ps
```

## Rulare workeri

Pornește workerii în trei terminale separate.

Ruby:

```bash
docker exec -it lab2_redis_streams_ruby_worker ruby ruby_computer.rb
```

Python:

```bash
docker exec -it lab2_redis_streams_python_worker python3 python_computer.py
```

C#:

```bash
docker exec -it lab2_redis_streams_csharp_worker dotnet run --project CSharpComputer/CSharpComputer.csproj
```

## Rulare server

În alt terminal:

```bash
docker exec -it lab2_redis_streams_producer ruby ruby_server.rb
```

Introdu dificultatea, de exemplu:

```text
6
```

Serverul afișează chunkurile trimise și primul rezultat valid primit.

## Oprire

```bash
./stop_cluster.sh
```
