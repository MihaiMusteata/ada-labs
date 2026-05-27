# Rezultate Laborator #2

## Scopul lucrării

Scopul lucrării este studierea modului în care componentele unui sistem pot fi decuplate cu ajutorul unui broker de mesaje. În cadrul laboratorului a fost folosit RabbitMQ pentru distribuirea calculului unui crypto-puzzle SHA-256 între mai multe aplicații de tip worker scrise în limbaje diferite.

Problema calculată este similară cu cea din Laboratorul 1: se caută un `nonce` care, concatenat cu mesajul `Hello World`, produce un hash SHA-256 care începe cu un număr prestabilit de zerouri.

## Descrierea implementării

Implementarea de bază conține aplicațiile Ruby `ruby_server.rb` și `ruby_computer.rb`. În varianta extinsă din `rabbit_mq`, sistemul a fost modificat astfel încât calculul să fie distribuit între trei aplicații de tip computer:

- `ruby_computer.rb` - worker Ruby;
- `python_computer.py` - worker Python, limbaj script based;
- `CSharpComputer/Program.cs` - worker C#, limbaj compilat.

Aplicația `ruby_server.rb` are rol de producer. Ea citește dificultatea puzzle-ului, creează mai multe taskuri și le trimite în coada RabbitMQ `crypto-puzzle-inquiries`. Pentru fiecare task este transmis un payload JSON cu următoarele câmpuri:

```json
{
  "string": "Hello World",
  "difficulty": 6,
  "start": 0,
  "step": 3
}
```

Distribuirea lucrului se face prin câmpurile `start` și `step`. Dacă există trei workeri, serverul trimite trei taskuri:

- workerul care primește `start = 0` verifică nonce-urile `0, 3, 6, 9...`;
- workerul care primește `start = 1` verifică nonce-urile `1, 4, 7, 10...`;
- workerul care primește `start = 2` verifică nonce-urile `2, 5, 8, 11...`.

Astfel, spațiul de căutare este împărțit între aplicații diferite, fără suprapunere. Primul worker care găsește soluția trimite răspunsul în coada de răspuns `crypto-puzzle-responses`, iar serverul afișează soluția și timpul total de execuție.

Pentru corelarea răspunsurilor cu cererea inițială se folosește un `correlation_id`, iar pentru primirea rezultatului serverul creează o coadă de răspuns prin proprietatea `reply_to`.

## Tipurile de decuplare obținute

Decuplarea funcțională este obținută deoarece serverul nu execută algoritmul de hash și nu depinde de implementarea internă a workerilor. El doar trimite taskuri în coadă și așteaptă un răspuns.

Decuplarea temporală este obținută deoarece producerul și consumerii comunică prin RabbitMQ. Ei nu trebuie să apeleze direct metode unii altora și pot fi porniți în procese sau containere diferite. În această implementare de laborator, cozile sunt configurate simplu, cu `auto_delete`, deci nu sunt gândite pentru persistență după restartul brokerului.

Decuplarea tehnologică este obținută deoarece workerii sunt scriși în Ruby, Python și C#. Fiecare aplicație folosește librăria potrivită limbajului ei, dar comunică prin același protocol și același format JSON.

## Măsurători experimentale

Fiecare abordare a fost executată de trei ori pentru dificultatea `6`, folosind toți cei trei workeri: Ruby, Python și C#. Timpul măsurat reprezintă timpul până la primul răspuns valid primit de server. Toate valorile sunt exprimate în milisecunde.

### Rezultate comparative pentru dificultatea 6

| Abordare | Run 1 | Run 2 | Run 3 | Media | Min | Max | Worker câștigător |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| RabbitMQ `start/step` | 637.81 | 561.13 | 559.78 | 586.24 | 559.78 | 637.81 | C# worker |
| RabbitMQ cu chunkuri | 593.02 | 505.16 | 511.94 | 536.71 | 505.16 | 593.02 | C# worker |
| Redis Lists cu chunkuri | 767.96 | 648.23 | 658.73 | 691.64 | 648.23 | 767.96 | C# worker |
| Redis Pub/Sub cu chunkuri | 1299.30 | 817.16 | 839.16 | 985.21 | 817.16 | 1299.30 | Python worker |
| Redis Streams cu chunkuri | 1349.80 | 1350.03 | 1346.88 | 1348.90 | 1346.88 | 1350.03 | Python worker |

### Detalii soluții găsite

| Abordare | Nonce | Hash |
| --- | ---: | --- |
| RabbitMQ `start/step` | 1439621 | `0000008a53e365f8f4145f2cf4b502b29949b24746484ef2b556aaa5e2d7a562` |
| RabbitMQ cu chunkuri | 1439621 | `0000008a53e365f8f4145f2cf4b502b29949b24746484ef2b556aaa5e2d7a562` |
| Redis Lists cu chunkuri | 1439621 | `0000008a53e365f8f4145f2cf4b502b29949b24746484ef2b556aaa5e2d7a562` |
| Redis Pub/Sub cu chunkuri | 1439621 | `0000008a53e365f8f4145f2cf4b502b29949b24746484ef2b556aaa5e2d7a562` |
| Redis Streams cu chunkuri | 1439621 | `0000008a53e365f8f4145f2cf4b502b29949b24746484ef2b556aaa5e2d7a562` |

Rezultatele arată că variantele RabbitMQ au fost cele mai rapide în aceste rulări. Varianta cu chunkuri a avut media puțin mai bună, deoarece distribuirea este dinamică: workerii mai rapizi pot primi lucru suplimentar după ce termină un chunk. Varianta `start/step` depinde mai mult de ordinea în care RabbitMQ livrează cele trei taskuri către workeri.

Implementările Redis au folosit același model de chunkuri, dar au avut overhead mai mare pentru coordonare. Redis Lists a fost cea mai rapidă dintre variantele Redis, Redis Pub/Sub a depins de protocolul request/reply implementat peste canale, iar Redis Streams a adăugat costul consumer group-ului și confirmărilor cu `XACK`.

## Probleme tehnice întâlnite și rezolvare

Prima problemă a fost comunicarea între aplicații scrise în limbaje diferite. Ruby, Python și C# folosesc librării diferite pentru RabbitMQ, dar mesajele au fost uniformizate prin JSON. Astfel, fiecare worker citește aceleași câmpuri: `string`, `difficulty`, `start` și `step`.

A doua problemă a fost împărțirea corectă a spațiului de căutare. Dacă toți workerii ar fi început de la același nonce, ei ar fi făcut același calcul și nu s-ar fi obținut accelerare. Soluția a fost folosirea strategiei `start + k * step`, unde `step` este egal cu numărul de workeri.

A treia problemă a fost colectarea rezultatului. Deoarece orice worker poate găsi primul soluția, serverul folosește o coadă de răspuns și ia în considerare primul mesaj primit. Pentru raportul de laborator această variantă este suficientă. Într-un sistem de producție ar fi necesar și un mecanism de anulare a taskurilor rămase după găsirea soluției.

A patra problemă a fost legată de datele locale RabbitMQ. În unele rulări, brokerul poate porni incorect dacă folderele persistente au permisiuni greșite. Soluția folosită este corectarea permisiunilor pentru `rabbitmq-data` sau recrearea folderului local de date.

A cincea problemă a fost gestionarea dependențelor. Python are nevoie de `pika`, Ruby de `bunny`, iar C# de `RabbitMQ.Client`. Pentru a evita instalări manuale pe sistemul gazdă, aplicațiile sunt rulate în containere Docker.

## Comparație cu soluția OpenMPI

| Criteriu | RabbitMQ | OpenMPI |
| --- | --- | --- |
| Model de comunicare | Mesaje prin broker, producer-consumer | Mesaje directe între procese MPI |
| Decuplare tehnologică | Foarte bună; workerii pot fi scriși în limbaje diferite | Mai slabă; procesele sunt de obicei parte din aceeași aplicație sau același ecosistem |
| Decuplare temporală | Bună; brokerul poate păstra taskuri, dacă se folosesc cozi durabile | Redusă; procesele MPI trebuie pornite împreună |
| Performanță brută | Mai mică din cauza brokerului și serializării JSON | De obicei mai bună pentru calcul numeric distribuit |
| Complexitate operațională | Necesită broker, cozi, routing, ack-uri și monitorizare | Necesită runtime MPI, hostfile, procese și configurare cluster |
| Scalare | Se pot adăuga workeri relativ ușor | Scalare bună în clustere HPC, dar mai rigidă la nivel de aplicație |
| Toleranță la defecte | Mai bună dacă se folosesc ack-uri, retry, cozi durabile și DLQ | Mai dificilă; căderea unui proces poate afecta execuția MPI |
| Potrivire | Sisteme distribuite, microservicii, joburi asincrone | Calcul paralel intens, HPC, aplicații științifice |

Pentru crypto-puzzle, OpenMPI este mai eficient dacă scopul principal este performanța brută, deoarece procesele comunică direct și nu există overhead de broker. RabbitMQ este mai flexibil deoarece permite combinarea workerilor scriși în tehnologii diferite și permite extinderea sistemului prin adăugarea de noi consumatori fără modificarea producerului.

## Analiza produselor de Queue și Broker de mesaje

Informațiile despre prețuri și restricții sunt rezumate pe baza documentațiilor oficiale consultate la 27 mai 2026.

| Produs / serviciu | Restricții tehnice | Preț | Calitatea documentației și exemplelor |
| --- | --- | --- | --- |
| RabbitMQ | Broker open-source, bazat pe cozi și exchange-uri. Suportă acknowledgements, routing, work queues, pub/sub, clustering și quorum queues. Pentru garanții bune sunt necesare cozi durabile, mesaje persistente și configurare corectă a ack-urilor. | RabbitMQ este gratuit sub licență open-source. Costul real apare la infrastructură, administrare, backup, monitorizare sau servicii managed oferite de cloud providers. | Documentație foarte bună, cu tutoriale pentru work queues, routing, pub/sub și exemple în mai multe limbaje. Este potrivit pentru laboratoare și aplicații enterprise. |
| Redis Pub/Sub | Foarte rapid și simplu, dar Pub/Sub are livrare `at-most-once`: dacă subscriberul este deconectat sau apare o eroare, mesajul se pierde. Nu este potrivit pentru joburi critice fără folosirea Redis Streams sau a unei soluții suplimentare. | Redis poate fi self-hosted. Redis Cloud are plan gratuit limitat și planuri plătite; pagina oficială indică Free până la 30 MB și Essentials de la aproximativ `$0.007/hour`, în funcție de regiune și resurse. | Documentația este clară pentru Pub/Sub, dar modelul este mai simplu decât la RabbitMQ. Pentru queue-uri fiabile trebuie studiat și Redis Streams. |
| Amazon SQS | Serviciu managed AWS. Standard queues oferă throughput foarte mare și livrare `at-least-once`, dar mesajele pot ajunge duplicate sau în altă ordine. FIFO queues oferă ordine mai strictă, dar cu restricții suplimentare. O cerere poate include 1-10 mesaje, cu limită totală de payload per request. | Model pay-as-you-go, fără taxă minimă. AWS oferă 1 milion de requesturi SQS gratuite pe lună; apoi se plătește în funcție de numărul de requesturi, tipul cozii și dimensiunea payloadului. | Documentație foarte bună, exemple pentru SDK-uri și integrare bună cu AWS Lambda, IAM, CloudWatch și alte servicii AWS. |
| Apache Kafka / Confluent Cloud | Kafka este mai mult un event log distribuit decât o coadă clasică. Este potrivit pentru streaming, replay, procesare de evenimente și volum mare de date. Necesită înțelegerea topicurilor, partițiilor, consumer groups și retenției. | Apache Kafka poate fi rulat self-hosted, cu cost de infrastructură și administrare. Confluent Cloud are plan Basic de la `$0/month`, Standard cu cost estimat de la aproximativ `$385/month`, plus costuri pentru throughput și stocare. | Documentația Confluent este foarte extinsă și are multe exemple, dar produsul este mai complex decât RabbitMQ sau SQS pentru cazuri simple de work queue. |

## Evaluare generală

RabbitMQ este alegerea cea mai potrivită pentru acest laborator deoarece oferă exact modelul necesar: producer, coadă de taskuri, mai mulți consumeri și răspuns asincron. Este ușor de rulat local cu Docker și permite integrarea aplicațiilor scrise în Ruby, Python și C#.

Redis Pub/Sub este foarte rapid, dar nu este suficient de sigur pentru taskuri de calcul unde nu vrem să pierdem mesaje. Pentru astfel de cazuri ar trebui folosit Redis Streams, nu Pub/Sub simplu.

Amazon SQS este foarte bun pentru aplicații cloud, mai ales când sistemul este deja în AWS. Avantajul principal este că nu trebuie administrat brokerul. Dezavantajul este dependența de AWS și costul bazat pe requesturi.

Kafka este foarte puternic pentru streaming și procesare de evenimente la scară mare, dar pentru laboratorul curent este mai complex decât este necesar. Pentru un simplu sistem producer-worker, RabbitMQ este mai direct și mai ușor de înțeles.

## Concluzii

Laboratorul demonstrează cum un broker de mesaje poate fi folosit pentru decuplarea componentelor unui sistem. Producerul Ruby nu depinde direct de workerii care execută calculul, iar workerii pot fi implementați în tehnologii diferite. RabbitMQ asigură comunicarea dintre componente și permite distribuirea taskurilor prin modelul producer-consumer.

Comparativ cu OpenMPI, soluția cu RabbitMQ nu este orientată spre performanță maximă în calcul paralel, ci spre flexibilitate, interoperabilitate și decuplare. Pentru aplicații de tip microservicii sau procesare asincronă, această abordare este mai naturală. Pentru calcule științifice intense și control strict al proceselor paralele, OpenMPI rămâne o soluție mai eficientă.
