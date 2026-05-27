# Rezultate Laborator #3

## Scopul lucrării

Scopul lucrării este configurarea unui sistem de monitorizare pentru o aplicație rulată în Docker, folosind Prometheus pentru colectarea metricilor și Grafana pentru vizualizare. În cadrul laboratorului este monitorizată aplicația `archive-api`, împreună cu metrici de sistem colectate prin Node Exporter.

Soluția finală se află în folderul `monitoring` și pornește prin Docker Compose următoarele componente:

- `archive-client` - interfața web a aplicației;
- `archive-api` - backend-ul .NET, care expune endpoint-ul `/metrics`;
- `archive-db` - baza de date PostgreSQL;
- `traefik` - reverse proxy pentru aplicația web;
- `prometheus` - colectorul de metrici;
- `grafana` - interfața pentru dashboard-uri;
- `node-exporter` - exporter pentru metrici de sistem.

## Descrierea implementării

Aplicația este pornită local cu Docker Compose. Serviciul `traefik` expune aplicația web la adresa `http://localhost:3232`, iar backend-ul `archive-api` rulează intern pe portul `8080`. Backend-ul expune deja endpoint-ul `/metrics`, de unde Prometheus colectează metricile aplicației.

Prometheus este configurat în fișierul `monitoring/prometheus/prometheus.yml`. Configurația folosește un interval de colectare de `5s` și definește două joburi:

```yaml
scrape_configs:
  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "archive-api"
    metrics_path: /metrics
    static_configs:
      - targets: ["archive-api:8080"]
```

Astfel, Prometheus colectează atât metrici de infrastructură, cât și metrici specifice aplicației.

Grafana este configurat cu provisioning automat pentru datasource. Fișierul `monitoring/grafana_datasources/prometheus.yml` creează datasource-ul `Prometheus`, cu URL-ul intern `http://prometheus:9090`, tip `prometheus`, acces `proxy` și `isDefault: true`. Din acest motiv, după pornirea proiectului, Grafana are deja conexiunea către Prometheus configurată.

Dashboard-ul exportat se află în `monitoring/dashboards/lab3-dashboard.json` și poate fi importat manual în Grafana.

## Organizarea proiectului

Structura principală a proiectului este:

```text
monitoring/
├── docker-compose.yml
├── README.md
├── start.sh
├── stop.sh
├── images/
│   ├── archive-api-lab3.tar
│   └── archive-client-lab3.tar
├── dashboards/
│   └── lab3-dashboard.json
├── prometheus/
│   └── prometheus.yml
├── grafana_datasources/
│   └── prometheus.yml
├── grafana_data/
└── prometheus_data/
```

Configurația Prometheus a fost mutată în folderul dedicat `prometheus/`, iar datasource-ul Grafana este definit separat în `grafana_datasources/`. Această organizare separă fișierele de configurare de fișierele principale ale proiectului și face structura mai clară pentru predare.

## Pornire și oprire

Pentru pornire:

```bash
cd monitoring
chmod +x start.sh stop.sh
./start.sh
```

Scriptul `start.sh` verifică dacă Docker și Docker Compose sunt disponibile. Apoi verifică imaginile locale `archive-api:lab3` și `archive-client:lab3`. Dacă imaginile lipsesc, acestea sunt încărcate automat din arhivele:

- `images/archive-api-lab3.tar`
- `images/archive-client-lab3.tar`

După verificări, scriptul execută:

```bash
docker compose up -d
```

Pentru oprire:

```bash
./stop.sh
```

Scriptul `stop.sh` execută `docker compose down` și nu șterge volumele implicit. Pentru reset complet se poate folosi:

```bash
docker compose down -v
```

## Linkuri servicii

| Serviciu | URL |
| --- | --- |
| Aplicație web | http://localhost:3232 |
| Prometheus | http://localhost:9090 |
| Prometheus targets | http://localhost:9090/targets |
| Grafana | http://localhost:3000 |
| Node Exporter | http://localhost:9100/metrics |

Credentialele Grafana sunt:

```text
admin / admin
```

## Metrici monitorizate

Dashboard-ul pentru laborator conține următoarele panouri:

| Panou | PromQL |
| --- | --- |
| API Requests per minute | `rate(http_requests_received_total[1m]) * 60` |
| API Memory Usage | `process_working_set_bytes / 1024 / 1024` |
| Node CPU Usage | `100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| Node Memory Usage | `100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))` |
| Node Disk Usage | `100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|rootfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|rootfs"})` |

Aceste metrici permit observarea încărcării aplicației, consumului de memorie al API-ului și stării generale a nodului Docker pe care rulează sistemul.

## Import dashboard Grafana

Dashboard-ul se importă manual în Grafana:

1. Se deschide `http://localhost:3000`.
2. Autentificare cu `admin / admin`.
3. Se alege `Dashboards`.
4. Se alege `New`.
5. Se alege `Import`.
6. Se încarcă fișierul `monitoring/dashboards/lab3-dashboard.json`.
7. Se selectează datasource-ul `Prometheus`, dacă Grafana cere acest lucru.

Datasource-ul Prometheus este deja configurat automat, deci importul dashboard-ului nu necesită configurarea manuală a URL-ului Prometheus.

## Verificări realizate

Configurația Docker Compose a fost verificată cu:

```bash
docker compose config
```

Comanda a confirmat că fișierul `monitoring/docker-compose.yml` este valid.

De asemenea, configurația Prometheus folosește calea nouă:

```text
./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
```

Nu există referințe către vechea cale `./prometheus.yml`.

## Concluzii

Laboratorul demonstrează modul în care Prometheus și Grafana pot fi integrate într-un sistem rulat cu Docker Compose. Prometheus colectează metrici atât din aplicația .NET, cât și din Node Exporter, iar Grafana oferă o interfață vizuală pentru analiza acestor metrici.

Prin provisioning, Grafana devine mai ușor de pornit și de predat, deoarece datasource-ul Prometheus este configurat automat. Separarea configurațiilor în foldere dedicate pentru Prometheus și Grafana face proiectul mai clar și mai ușor de verificat.

Soluția finală permite pornirea completă a aplicației, monitorizarea backend-ului și importul unui dashboard Grafana fără pași suplimentari de configurare manuală în Prometheus.
