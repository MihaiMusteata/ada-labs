# Redis Pub/Sub cu chunkuri

Aceasta este varianta Redis Pub/Sub în care serverul împarte spațiul de căutare în intervale finite de nonce-uri. Deoarece Pub/Sub nu este queue, implementarea folosește un protocol request/reply între server și workerii Ruby, Python și C#.

## Distribuire taskuri

Workerii cer lucru prin canalul `puzzle:requests`, iar serverul trimite chunkuri pe canale private de forma `puzzle:tasks:<worker_id>`.

Exemplu:

```text
chunk 1: 0..499999
chunk 2: 500000..999999
chunk 3: 1000000..1499999
```

Workerii trimit rezultatele prin canalul `puzzle:results`. Dacă un worker termină un chunk și nu găsește soluția, trimite `not_found`, iar serverul trimite următorul chunk când primește o nouă cerere. Dacă un worker găsește soluția, trimite `found`, serverul afișează rezultatul și publică oprirea pe canalul `puzzle:cancel`.

Serverul nu trimite toate chunkurile deodată. El trimite chunkuri doar către workerii care cer lucru. Redis este expus local pe portul `6382`.

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
docker exec -it lab2_redis_pub_sub_ruby_worker ruby ruby_computer.rb
```

Python:

```bash
docker exec -it lab2_redis_pub_sub_python_worker python3 python_computer.py
```

C#:

```bash
docker exec -it lab2_redis_pub_sub_csharp_worker dotnet run --project CSharpComputer/CSharpComputer.csproj
```

## Rulare server

În alt terminal:

```bash
docker exec -it lab2_redis_pub_sub_producer ruby ruby_server.rb
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
