# RabbitMQ cu start/step

Aceasta este varianta RabbitMQ în care serverul împarte spațiul de căutare în trei progresii aritmetice. Workerii Ruby, Python și C# citesc din aceeași coadă și caută soluția în paralel.

## Distribuire taskuri

Serverul trimite trei taskuri în coada `crypto-puzzle-inquiries`:

```text
start=0, step=3
start=1, step=3
start=2, step=3
```

RabbitMQ livrează fiecare task către un singur worker disponibil. Fiecare worker verifică nonce-urile care respectă perechea `start/step`, de exemplu `0, 3, 6, 9...` pentru primul task.

Dacă un worker găsește soluția, trimite rezultatul către server. Serverul afișează primul rezultat valid primit și publică un mesaj de anulare prin exchange-ul `crypto-puzzle-cancel`, astfel încât ceilalți workeri să oprească procesarea.

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
docker exec -it lab2_ruby_consumer ruby ruby_computer.rb
```

Python:

```bash
docker exec -it lab2_python_consumer python3 python_computer.py
```

C#:

```bash
docker exec -it lab2_csharp_consumer dotnet run --project CSharpComputer/CSharpComputer.csproj
```

## Rulare server

În alt terminal:

```bash
docker exec -it lab2_producer ruby ruby_server.rb
```

Introdu dificultatea, de exemplu:

```text
6
```

Serverul afișează taskurile trimise și primul rezultat valid primit.

## Oprire

```bash
./stop_cluster.sh
```
