# Varianta OpenMP

Aceasta implementare foloseste OpenMP pentru paralelizarea rezolvarii crypto-puzzle-ului SHA-256 pe mesajul `Hello World`.

Parametrul `n` reprezinta dificultatea, adica numarul de zerouri cerute la inceputul hash-ului.

## Compilare si rulare in Docker

Din folderul `openmp` ruleaza:

```bash
./build_container.sh
./start_container.sh
```

Dupa pornirea containerului, ruleaza in interiorul lui:

```bash
./compile.sh
```

## Rulare

Format:

```bash
./lab1_openmp <dificultate> [numar_fire]
```

Daca nu se transmite `numar_fire`, programul ruleaza automat pentru `1, 2, 4, 8, 16, 32` fire.

Exemple:

```bash
./lab1_openmp 6
./lab1_openmp 6 8
./lab1_openmp 7 32
```

Primul exemplu ruleaza toate cazurile de fire pentru dificultatea `6`. Al doilea ruleaza doar cu `8` fire.

## Exemplu pentru 3 rulari

```bash
for i in 1 2 3; do ./lab1_openmp 6 8; done
```

Programul afiseaza numarul de fire, solutia gasita si timpul de executie in milisecunde.

## Rulare locala fara Docker

Daca sistemul are `g++` cu suport OpenMP, se poate rula direct:

```bash
./compile.sh
./lab1_openmp 6 8
```
