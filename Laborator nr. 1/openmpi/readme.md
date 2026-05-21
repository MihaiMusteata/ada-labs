# Varianta OpenMPI

Aceasta implementare foloseste OpenMPI pentru rularea crypto-puzzle-ului SHA-256 intr-un cluster Docker simulat.

Varianta `openmpi` porneste 32 de containere, fiecare cu `slots=1`.

Parametrul `n` reprezinta dificultatea, adica numarul de zerouri cerute la inceputul hash-ului.

## Pregatire

Din folderul `openmpi` ruleaza:

```bash
./build_container.sh
```

## Rulare cluster

Format:

```bash
./start_cluster.sh <dificultate> [numar_procese]
```

Daca nu se transmite `numar_procese`, scriptul ruleaza automat pentru `1, 2, 4, 8, 16, 32` procese MPI.

Exemple:

```bash
./start_cluster.sh 6
./start_cluster.sh 6 16
./start_cluster.sh 7 32
```

Primul exemplu ruleaza toate cazurile de procese pentru dificultatea `6`. Al doilea ruleaza doar cu `16` procese.

La pornire, scriptul:

- construieste sau actualizeaza containerele prin Docker Compose
- compileaza aplicatia in container
- regenereaza `available_hosts_file`
- ruleaza `run_computations_on_cluster.sh`

## Rulare manuala in container

Dupa ce clusterul este pornit, se poate rula manual:

```bash
./run_computations_on_cluster.sh 6
./run_computations_on_cluster.sh 6 8
```

Pentru rulare directa cu `mpirun`:

```bash
mpirun --hostfile available_hosts_file -np 8 lab1_openmpi 6
```

## Oprire cluster

```bash
./stop_cluster.sh
```

Programul afiseaza procesul MPI care gaseste solutia si timpul de executie in milisecunde.
