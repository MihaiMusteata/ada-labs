# Varianta default

Aceasta este implementarea secventiala pentru crypto-puzzle-ul SHA-256 pe mesajul `Hello World`.

Parametrul `n` reprezinta dificultatea, adica numarul de zerouri cerute la inceputul hash-ului.

## Compilare

Din folderul `default` ruleaza:

```bash
./compile.sh
```

Scriptul compileaza aplicatia cu `g++` si genereaza executabilul `lab1`.

## Rulare

Format:

```bash
./lab1 <dificultate>
```

Exemple:

```bash
./lab1 5
./lab1 6
./lab1 7
```

Programul afiseaza mesajul initial, hash-ul mesajului, solutia gasita si timpul de executie in milisecunde.

## Exemplu pentru 3 rulari

```bash
for i in 1 2 3; do ./lab1 6; done
```
