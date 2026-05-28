# Anàlisi i evolució de la infraestructura de transport en un node d’agregació per a operadors FTTH

Aquest repositori recull tot el material complementari, scripts d'automatització i entorn de simulació del **Treball Final de Màster (TFM) en Enginyeria de Telecomunicacions** realitzat a la **Universitat Oberta de Catalunya (UOC)**.

L'objectiu del projecte és dimensionar, caracteritzar i simular l'evolució d'un node d'agregació real (R6) que interconnecta diferents operadors de fibra òptica (FTTH) amb proveïdors de tràfic de trànsit global, Punts d'Intercanvi (IXP) i proveïdors de contingut específics (CDNs).

---

## Estructura del Repositori

El repositori està organitzat en dues grans àrees de treball:

* **`documentacio/`**: Conté els gràfics analítics, els fulls de càlcul de dimensionament, les projeccions de tràfic per fases evolutives (Fases 0 a 5) i els models matemàtics utilitzats per a la caracterització del node.
* **`lab/`**: Programari, topologies i scripts necessaris per a muntar, simular i posar a prova el node d'agregació virtualitzat.
    * **`config/`**: Fitxers de configuració dels dimonis d'encaminament per a cada contenidor.
    * **`tests/`**: Suite de proves d'estrès, convergència i injecció de fallades.

---

## Arquitectura del Laboratori Virtual

L'entorn de simulació està basat en **Docker**, replicant una infraestructura d'operador d'alta fidelitat mitjançant virtualització lleugera:

* **Node Agregador (R6):** Instància basada en **FRRouting (FRR)** que gestiona múltiples interfícies virtuals cap als proveïdors i implementa polítiques de QoS estrictes.
* **Nodes Proveïdors / Trànsit:** Contenidors FRR que simulen les respostes d'enrutament dinàmic BGP.
* **Nodes Clients (OP01 - OP09):** Contenidors basats en **Alpine Linux** que actuen com a operadors FTTH, generant demandes asimètriques de tràfic cap a la xarxa.

---

## Components d'Automatització Implementats

Per a fer viable l'anàlisi evolutiva, s'han programat tres eines clau:

### 1. `set_interfaces.sh` (Configuració de topologia i QoS)
Executat a **R6**, aquest script aplica de forma **acumulativa** les capacitats i amples de banda de cada enllaç segons la fase del projecte (Fase 0 a Fase 5). 
* Implementa control de tràfic mitjançant **Linux TC (Token Bucket Filter)**.
* Gestiona dinàmicament l'estat operatiu dels enllaços, apagant (`ip link set dev ... down`) les interfícies no utilitzades o alliberades en cada fase per a una simulació realista.

### 2. `generate_traffic.sh` (Injecció de tràfic asimètric)
Executat a cada un dels 9 nodes clients. Genera fluxos constants i automatitzats mitjançant **iperf3 (UDP)** directament cap a les IPs dels proveïdors de contingut (Google, Netflix, Meta, Espanix, Hurricane, etc.). El tràfic injectat es calcula en temps real aplicant matrius de proporció exactes basades en el dimensionament teòric del TFM.
* Admet el paràmetre `stop` per a una neteja immediata de processos en segon pla.

### 3. `run_tests.sh` (Orquestrador de proves)
El motor de tests automatitzats. Itera cíclicament per cada fase (0-5) i, dins de cada una, força **10 escenaris diferents d'estrès i fallades** (caiguda de CDNs individuals, fallades simultànies com `Meta + Google`, etc.).
* **Mecanisme:** Tomba les interfícies a R6, espera el temps de convergència dels protocols, executa les bateries de captures i torna a aixecar l'enllaç netejant residus.

---

## Execució dels Tests

La finalitat de les proves és la de validar els objectius establerts a continuació:

 - Ocupació <80%
 
 - Pèrdua de paquets negligible (<1%)
 
 - Latència <20ms
 
 - Jitter <5ms

Totes les proves de rendiment, pings de latència, jitter i ocupació de les interfícies s'executen de manera desatesa. Per llançar la bateria completa de tests de la memòria del TFM i recollir completament les dades generades, s'executa el següent comandament des de l'arrel del directori de tests:

```
tests/run_tests.sh > tests/resultats/dump.log
```

---

## Captura de Resultats, Validació i Mètriques

L'orquestrador genera automàticament una sèrie de fitxers on documentarà el procés:

 - Un fitxer de log independent per a cada escenari i fase (ex: tests/resultats/fase_3/test_Falla_Espanix.log).

 - Mesures precises del percentatge de paquets perduts (% Loss) i fluctuació del retard (Jitter) de cada operador FTTH cap al seu destí sota condicions de criticitat. (ex: tests/resultats/tmp/ping_OP01-ADZ_8.8.4.4_A)

 - Un resum on es pot determinar d'una ullada si s'han superat els tests o si pel contrari alguna prova no ha complert els objectius requerits. (ex: tests/resultats/resultats_tests_20260520_134603.log)

 - Un informe final on es detalla tot el procediment. (ex: tests/resultats/dump.log)

**/!\\ Atenció**: Cada escenari tarda uns 6 minuts en excutar-se. Es proben 10 escenaris diferents a cada fase, i hi ha 6 fases (0-5).
     Això fa que el temps total d'execució per tal de validar el model sigui d'unes **6,5 hores (390m 53s)**.
     Aquests temps són necessaris i s'han de respectar per tal que els sistemes convergeixin correctament i es puguin treure estadístiques coherents.

---

## Autor

Estudiant: Joan Enric Bonnin Sans

Programa: Màster Universitari en Enginyeria de Telecomunicacions (UOC)

Àrea: Telemàtica

Tutor: José López Vicario

Data: juny 2026