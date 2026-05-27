# RabbitMQ cu chunkuri

Aceasta este varianta RabbitMQ în care serverul împarte spațiul de căutare în intervale finite de nonce-uri. Workerii Ruby, Python și C# citesc din aceeași coadă, iar workerii mai rapizi pot primi mai multe chunkuri.

## Distribuire taskuri

Serverul trimite chunkuri în coada `crypto-puzzle-chunks`.

Exemplu:

```text
chunk 1: 0..499999
chunk 2: 500000..999999
chunk 3: 1000000..1499999
```

Dacă un worker termină un chunk și nu găsește soluția, trimite `not_found`, iar serverul trimite următorul chunk. Dacă un worker găsește soluția, trimite `found`, serverul afișează rezultatul și publică un mesaj de anulare prin exchange-ul `crypto-puzzle-cancel`.

Serverul nu trimite toate chunkurile deodată. El menține o fereastră limitată:

```text
WINDOW_SIZE = WORKERS_COUNT * 2
```

Pentru 3 workeri, în sistem sunt cel mult 6 chunkuri active.

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
docker exec -it lab2_chunk_ruby_consumer ruby ruby_computer.rb
```

Python:

```bash
docker exec -it lab2_chunk_python_consumer python3 python_computer.py
```

C#:

```bash
docker exec -it lab2_chunk_csharp_consumer dotnet run --project CSharpComputer/CSharpComputer.csproj
```

## Rulare server

În alt terminal:

```bash
docker exec -it lab2_chunk_producer ruby ruby_server.rb
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
