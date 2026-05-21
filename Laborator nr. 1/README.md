# Rezultate Laborator #1

## Scopul lucrării

Scopul lucrării este studierea tehnicilor de programare paralelă și distribuită în C++ folosind OpenMP și OpenMPI. Pentru experiment a fost folosit un crypto-puzzle bazat pe SHA-256, unde se caută un nonce care, adăugat mesajului "Hello World", produce un hash care începe cu un număr prestabilit de zerouri.

## Descrierea implementării

În varianta secvențială, programul verifică nonce-urile unul câte unul, începând de la 0, până când găsește un hash SHA-256 care începe cu numărul cerut de zerouri.

În varianta OpenMP, spațiul de căutare este împărțit între fire de execuție. Fiecare thread primește un ID prin `omp_get_thread_num()` și numărul total de thread-uri prin `omp_get_num_threads()`. Astfel, thread-ul cu ID-ul `k` verifică valorile `k, k + total_threads, k + 2 * total_threads` etc.

În varianta OpenMPI, aceeași idee este aplicată folosind procese. Fiecare proces primește un `rank` prin `MPI_Comm_rank()` și numărul total de procese prin `MPI_Comm_size()`. Procesul cu rank-ul `k` verifică valorile `k, k + world_size, k + 2 * world_size` etc.

## Utilitatea și limitările OpenMP și OpenMPI

OpenMP este util pentru paralelizarea aplicațiilor pe un singur calculator multicore. Este relativ simplu de utilizat, deoarece permite introducerea paralelismului prin directive `#pragma`, iar firele de execuție partajează aceeași memorie. Din acest motiv, comunicarea între thread-uri este mai simplă și mai rapidă. Limitarea principală este că OpenMP este potrivit în special pentru sisteme cu memorie comună și nu scalează direct pe mai multe calculatoare.

OpenMPI este util pentru programarea distribuită, unde mai multe procese pot rula pe noduri diferite. Este potrivit pentru clustere și sisteme distribuite, dar este mai complex decât OpenMP, deoarece procesele au memorie separată și trebuie să comunice explicit prin mesaje. În plus, în cazul rulării în Docker, apar costuri suplimentare legate de containere, SSH, hostfile și comunicarea prin rețeaua virtuală.

În acest laborator, OpenMP este mai avantajos pentru execuția locală pe același procesor, în timp ce OpenMPI demonstrează principiul distribuției lucrului între procese separate.

## Exemplu de sistem paralel și secvențial

Un exemplu real este un server web. Acesta poate procesa mai multe cereri de la utilizatori în paralel, deoarece cererile sunt în mare parte independente. Totuși, anumite operații pot rămâne secvențiale, cum ar fi scrierea într-un fișier comun, accesul la o resursă blocată sau actualizarea unei baze de date. Astfel, gradul de paralelism este mare pentru cererile independente, dar performanța finală este limitată de operațiile care necesită sincronizare.

În cazul crypto-puzzle-ului, verificarea hash-urilor pentru nonce-uri diferite este aproape complet paralelizabilă, deoarece fiecare verificare este independentă. Partea secvențială este formată din inițializarea programului, citirea argumentelor, pornirea firelor/proceselor, sincronizarea și afișarea rezultatului.

Toate valorile de timp din tabele sunt exprimate in milisecunde (ms).
## Structura directoriului
* default - implementarea de bază a algoritmul de rezolvare a cripto-puzzle-ului
* openmp - structura de bază a implementării algoritmului cu ajutorul librăriei openmp
* openmpi - structura de bază a implementării algorimului cu ajutorul librăriei openmpi
* openmpi-v2 - variantă openmpi pentru test cu 2 containere, 16 sloturi/container

## Rezultate default
| n | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 5 | 350 | 447 | 355 | 384 | 350 | 447 |
| 6 | 1026 | 860 | 912 | 932.667 | 860 | 1026 |
| 7 | 135829 | 135006 | 135024 | 135286.333 | 135006 | 135829 |

## Rezultate OpenMP detaliate
### OpenMP, n = 5
| Numar fire | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 363 | 374 | 432 | 389.667 | 363 | 432 |
| 2 | 198 | 264 | 276 | 246 | 198 | 276 |
| 4 | 259 | 161 | 176 | 198.667 | 161 | 259 |
| 8 | 191 | 278 | 267 | 245.333 | 191 | 278 |
| 16 | 472 | 142 | 107 | 240.333 | 107 | 472 |
| 32 | 48 | 164 | 110 | 107.333 | 48 | 164 |

### OpenMP, n = 6
| Numar fire | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 885 | 967 | 998 | 950 | 885 | 998 |
| 2 | 553 | 569 | 555 | 559 | 553 | 569 |
| 4 | 381 | 401 | 375 | 385.667 | 375 | 401 |
| 8 | 304 | 345 | 535 | 394.667 | 304 | 535 |
| 16 | 330 | 363 | 277 | 323.333 | 277 | 363 |
| 32 | 561 | 156 | 116 | 277.667 | 116 | 561 |

### OpenMP, n = 7
| Numar fire | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 137797 | 136462 | 135860 | 136706.333 | 135860 | 137797 |
| 2 | 75876 | 68055 | 67861 | 70597.333 | 67861 | 75876 |
| 4 | 35456 | 35741 | 36169 | 35788.667 | 35456 | 36169 |
| 8 | 23017 | 24304 | 23390 | 23570.333 | 23017 | 24304 |
| 16 | 23859 | 21538 | 20965 | 22120.667 | 20965 | 23859 |
| 32 | 26105 | 23516 | 21279 | 23633.333 | 21279 | 26105 |

## Tabel compact OpenMP
| Numar fire | 1 | 2 | 4 | 8 | 16 | 32 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Timp mediu n=5 | 389.667 | 246 | 198.667 | 245.333 | 240.333 | 107.333 |
| Timp mediu n=6 | 950 | 559 | 385.667 | 394.667 | 323.333 | 277.667 |
| Timp mediu n=7 | 136706.333 | 70597.333 | 35788.667 | 23570.333 | 22120.667 | 23633.333 |

## Rezultate OpenMPI detaliate
### OpenMPI v1, n = 5
| Numar procese | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 327.469 | 302.76 | 296.48 | 308.903 | 296.48 | 327.469 |
| 2 | 295.869 | 272.918 | 297.252 | 288.68 | 272.918 | 297.252 |
| 4 | 78.632 | 70.893 | 76.827 | 75.451 | 70.893 | 78.632 |
| 8 | 34.906 | 47.31 | 44.549 | 42.255 | 34.906 | 47.31 |
| 16 | 29.468 | 19.569 | 32.385 | 27.141 | 19.569 | 32.385 |
| 32 | 26.238 | 205.678 | 166.558 | 132.825 | 26.238 | 205.678 |

### OpenMPI v1, n = 6
| Numar procese | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 626.366 | 626.428 | 652.7 | 635.165 | 626.366 | 652.7 |
| 2 | 761.263 | 623.301 | 637.519 | 674.028 | 623.301 | 761.263 |
| 4 | 163.732 | 156.797 | 163.508 | 161.346 | 156.797 | 163.732 |
| 8 | 87.836 | 87.329 | 90.205 | 88.457 | 87.329 | 90.205 |
| 16 | 81.223 | 154.572 | 128.432 | 121.409 | 81.223 | 154.572 |
| 32 | 104.93 | 128.799 | 27.268 | 86.999 | 27.268 | 128.799 |

### OpenMPI v1, n = 7
| Numar procese | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 137759 | 134938 | 136957 | 136551.333 | 134938 | 137759 |
| 2 | 135986 | 136737 | 136010 | 136244.333 | 135986 | 136737 |
| 4 | 34936.3 | 35060.2 | 34869.8 | 34955.433 | 34869.8 | 35060.2 |
| 8 | 22373.8 | 21419.4 | 23346.2 | 22379.8 | 21419.4 | 23346.2 |
| 16 | 25214.1 | 23802.8 | 19699.1 | 22905.333 | 19699.1 | 25214.1 |
| 32 | 22319.4 | 22488.8 | 24397.5 | 23068.567 | 22319.4 | 24397.5 |

## Tabel compact OpenMPI v1
| Numar procese | 1 | 2 | 4 | 8 | 16 | 32 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Timp mediu n=5 | 308.903 | 288.68 | 75.451 | 42.255 | 27.141 | 132.825 |
| Timp mediu n=6 | 635.165 | 674.028 | 161.346 | 88.457 | 121.409 | 86.999 |
| Timp mediu n=7 | 136551.333 | 136244.333 | 34955.433 | 22379.8 | 22905.333 | 23068.567 |

Nota: `openmpi-v2` a fost testat suplimentar pentru comparatie. Au fost masurate direct procesele 4, 8, 16 si 32. Valorile pentru 1 si 2 procese sunt calculate prin extrapolare, nu masurate direct.
Calculul folosit: `T1 = 4 * T4`, `T2 = 2 * T4`, pe fiecare rulare, pornind de la cel mai mic numar de procese masurat (`p=4`).
Topologie: folderul `openmpi-v2`, 2 containere, `slots=16` pe fiecare container, total 32 sloturi MPI.

## Rezultate OpenMPI v2 detaliate
### OpenMPI v2, n = 5
| Numar procese | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 277.034 | 270.881 | 273.319 | 273.745 | 270.881 | 277.034 |
| 2 | 138.517 | 135.44 | 136.66 | 136.872 | 135.44 | 138.517 |
| 4 | 69.258 | 67.72 | 68.33 | 68.436 | 67.72 | 69.258 |
| 8 | 39.712 | 47.977 | 41.592 | 43.094 | 39.712 | 47.977 |
| 16 | 43.552 | 22.233 | 43.398 | 36.394 | 22.233 | 43.552 |
| 32 | 86.002 | 33.576 | 55.966 | 58.514 | 33.576 | 86.002 |

### OpenMPI v2, n = 6
| Numar procese | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 649.444 | 647.712 | 638.264 | 645.14 | 638.264 | 649.444 |
| 2 | 324.722 | 323.856 | 319.132 | 322.57 | 319.132 | 324.722 |
| 4 | 162.361 | 161.928 | 159.566 | 161.285 | 159.566 | 162.361 |
| 8 | 107.331 | 89.984 | 98.336 | 98.55 | 89.984 | 107.331 |
| 16 | 119.85 | 167.926 | 121.124 | 136.3 | 119.85 | 167.926 |
| 32 | 118.553 | 101.428 | 86.805 | 102.262 | 86.805 | 118.553 |

### OpenMPI v2, n = 7
| Numar procese | Run 1 | Run 2 | Run 3 | Media | Min | Max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 139220.8 | 138439.2 | 139161.6 | 138940.533 | 138439.2 | 139220.8 |
| 2 | 69610.4 | 69219.6 | 69580.8 | 69470.267 | 69219.6 | 69610.4 |
| 4 | 34805.2 | 34609.8 | 34790.4 | 34735.133 | 34609.8 | 34805.2 |
| 8 | 20301.6 | 20028.5 | 20791.2 | 20373.767 | 20028.5 | 20791.2 |
| 16 | 22926 | 19644.6 | 21263.7 | 21278.1 | 19644.6 | 22926 |
| 32 | 19783 | 18888.1 | 18846.4 | 19172.5 | 18846.4 | 19783 |

## Tabel compact OpenMPI v2
| Numar procese | 1 | 2 | 4 | 8 | 16 | 32 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Timp mediu n=5 | 273.745 | 136.872 | 68.436 | 43.094 | 36.394 | 58.514 |
| Timp mediu n=6 | 645.14 | 322.57 | 161.285 | 98.55 | 136.3 | 102.262 |
| Timp mediu n=7 | 138940.533 | 69470.267 | 34735.133 | 20373.767 | 21278.1 | 19172.5 |

## Speedup
Speedup = T1 / Tp

### Speedup OpenMP
| n | 1 | 2 | 4 | 8 | 16 | 32 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 5 | 1 | 1.584 | 1.961 | 1.588 | 1.621 | 3.63 |
| 6 | 1 | 1.699 | 2.463 | 2.407 | 2.938 | 3.421 |
| 7 | 1 | 1.936 | 3.82 | 5.8 | 6.18 | 5.784 |

### Speedup OpenMPI v1
| n | 1 | 2 | 4 | 8 | 16 | 32 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 5 | 1 | 1.07 | 4.094 | 7.31 | 11.381 | 2.326 |
| 6 | 1 | 0.942 | 3.937 | 7.181 | 5.232 | 7.301 |
| 7 | 1 | 1.002 | 3.906 | 6.102 | 5.962 | 5.919 |

### Speedup OpenMPI v2
| n | 1 | 2 | 4 | 8 | 16 | 32 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 5 | 1 | 2 | 4 | 6.352 | 7.522 | 4.678 |
| 6 | 1 | 2 | 4 | 6.546 | 4.733 | 6.309 |
| 7 | 1 | 2 | 4 | 6.82 | 6.53 | 7.247 |

## Analiza conform Legii lui Amdahl

Legea lui Amdahl estimeaza accelerarea maxima obtinuta prin paralelizare folosind formula:

`S(p) = 1 / ((1 - P) + P / p)`

In aceasta formula, `S(p)` este speedup-ul pentru `p` fire sau procese, iar `P` este partea din program care poate fi paralelizata. Partea `1 - P` ramane secventiala si limiteaza accelerarea maxima, indiferent cate fire sau procese sunt folosite.

Pentru crypto-puzzle-ul SHA-256, verificarea nonce-urilor este in mare parte paralelizabila, deoarece fiecare fir sau proces poate testa un set diferit de valori independent. Totusi, accelerarea nu este liniara, asa cum se observa si in tabelele din README, deoarece exista overhead de initializare, sincronizare, comunicare si afisare. In plus, dupa un anumit numar de fire sau procese, resursele hardware disponibile devin limitate, iar costurile suplimentare pot reduce beneficiul paralelizarii.

OpenMP are in general overhead mai mic pe acelasi calculator, deoarece firele ruleaza in acelasi proces si partajeaza memoria. OpenMPI are overhead mai mare, fiind bazat pe procese separate, mesaje, Docker, SSH si hostfile, dar este mai potrivit pentru clustere reale, unde procesele pot rula pe noduri diferite.

## De ce MD5 nu este sigur pentru stocarea parolelor

MD5 nu mai este considerat sigur pentru stocarea parolelor deoarece este un algoritm foarte rapid si are vulnerabilitati criptografice cunoscute. Daca un atacator obtine o baza de date cu hash-uri MD5, poate incerca sa recupereze parolele prin atacuri brute-force, atacuri de dictionar sau rainbow tables. Problema nu este doar existenta coliziunilor in MD5, ci si faptul ca algoritmul este prea rapid pentru parole: permite testarea unui numar foarte mare de parole candidate intr-un timp redus.

Practica moderna este ca fiecare parola sa fie combinata cu un salt unic inainte de procesare, astfel incat aceeasi parola sa nu produca acelasi rezultat pentru utilizatori diferiti si sa fie mai greu de folosit tabele precompute. Pentru stocarea parolelor trebuie utilizati algoritmi specializati si lenti, proiectati pentru acest scop, precum `bcrypt`, `scrypt`, `Argon2` sau `PBKDF2`. In schimb, algoritmi generali si rapizi precum `MD5`, `SHA-1` sau `SHA-256` simplu trebuie evitati pentru stocarea parolelor.

## Concluzii

Rezultatele obtinute arata ca problema crypto-puzzle-ului SHA-256 se preteaza bine la paralelizare, deoarece verificarea nonce-urilor poate fi impartita intre fire sau procese independente. Variantele OpenMP si OpenMPI reduc timpul de executie fata de varianta secventiala, in special pentru dificultati mai mari, unde volumul de lucru este suficient de mare pentru a justifica paralelizarea.

Accelerarea nu este perfect liniara, deoarece executia include si parti secventiale, precum initializarea, pornirea firelor sau proceselor, sincronizarea si afisarea rezultatului. In plus, la un numar mare de fire sau procese apar costuri suplimentare si limitari hardware, ceea ce explica diferentele observate in tabelele de speedup.

OpenMP este mai potrivit pentru rularea pe un singur calculator multicore, avand overhead mai mic si comunicare mai simpla intre fire. OpenMPI este mai costisitor in acest experiment, mai ales din cauza rularii prin Docker si a comunicarii intre procese, dar ramane solutia potrivita pentru scenarii distribuite si clustere reale.
