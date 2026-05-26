# Laboratorul 3 - Prometheus + Grafana

Proiectul porneste o aplicatie web, backend-ul `archive-api`, baza de date PostgreSQL, Prometheus, Grafana si Node Exporter folosind Docker Compose.

## Pornire

```bash
chmod +x start.sh stop.sh
./start.sh
```

Scriptul verifica existenta Docker si Docker Compose, verifica imaginile locale `archive-api:lab3` si `archive-client:lab3`, iar daca lipsesc le incarca din:

- `images/archive-api-lab3.tar`
- `images/archive-client-lab3.tar`

## Oprire

```bash
./stop.sh
```

Comanda opreste containerele fara sa stearga volumele.

## Reset complet

```bash
docker compose down -v
```

Aceasta comanda sterge si volumele Docker create de compose.

## Linkuri servicii

- Aplicație web: http://localhost:3232
- Prometheus: http://localhost:9090
- Prometheus targets: http://localhost:9090/targets
- Grafana: http://localhost:3000
- Node Exporter: http://localhost:9100/metrics

## Grafana

- Username: `admin`
- Password: `admin`
- Datasource: `Prometheus`
- URL datasource: `http://prometheus:9090`

Datasource-ul Prometheus este configurat automat prin provisioning din `grafana_datasources/prometheus.yml`.

## Import dashboard

In Grafana:

1. Deschide `Dashboards`.
2. Alege `New`.
3. Alege `Import`.
4. Incarca fisierul `dashboards/lab3-dashboard.json`.
5. Selecteaza datasource-ul `Prometheus`, daca Grafana cere acest lucru.

## Metrici monitorizate

- API Requests per minute
- API Memory Usage
- Node CPU Usage
- Node Memory Usage
- Node Disk Usage

## Configurare Prometheus

Prometheus foloseste configuratia din `prometheus/prometheus.yml` si colecteaza:

- metrici de nod de la `node-exporter:9100`
- metrici de aplicatie de la `archive-api:8080/metrics`
