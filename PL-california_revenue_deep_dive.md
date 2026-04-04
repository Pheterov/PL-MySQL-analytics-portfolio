# Historia przychodów Kalifornii: od fałszywego alarmu do rzeczywistego wniosku

> **Portfolio SQL · Analityka E-Commerce**
> Autor: Piotr Rzepka · Baza danych: `supersales` (MySQL 8.0+) · Okres: 2018–2022

> **Nota analityczna:** Projekt powstał jako ćwiczenie z analizy danych, z wsparciem AI na etapie code review. Metodologia analityczna — kontrola tenure bias, right-censoring, dekompozycja przychodów — została wypracowana w ramach mentoringu. Cały kod SQL jest mojego autorstwa, napisany i zweryfikowany na działającej bazie danych.

---

## Kluczowe liczby w skrócie

| Metryka | Wartość |
|---|---|
| Łączny przychód Kalifornii | 451 451 $ — #1 wśród wszystkich stanów |
| Przeanalizowane zamówienia | 1 021 (2018–2021 pełne lata; 2022 = wyłącznie styczeń) |
| Segmenty klientów | 4 segmenty podzielone na podstawie przychodu i powtarzalności zakupów |
| Wskaźnik ponownych zakupów w oknie 90-dniowym | 3,75% (2018) → 7,06% (2021) — trend rosnący |
| Udział przychodów od powracających klientów (2021-Q4) | 63% kwartalnego przychodu |

---

## Wnioski

Kalifornia jest najlepiej performującym stanem w tym zbiorze danych e-commerce — pod względem łącznego przychodu, liczby zamówień i wolumenu klientów. Jednak powierzchowna interpretacja danych jest myląca w sposób, który odsłania fundamentalne zasady rzetelnej analizy.

Segmentacja oparta na pełnej historii zakupowej klientów wskazuje na wyraźną zmianę: od 2021 roku nowe akwizycje przesunęły się w stronę niskouwartościowych, jednorazowych kupujących. Segment top_customer niemal zniknął z najnowszych kohort. Naturalny wniosek — że jakość akwizycji się pogarsza — wydaje się potwierdzony przez dane.

**Ten wniosek jest błędny.**

Jest artefaktem tenure bias: klienci pozyskani w 2018 roku mieli cztery lata na akumulację przychodu i ponownych zakupów, podczas gdy klienci z 2021 roku — zaledwie kilka miesięcy. Gdy każda kohorta dostaje to samo 90-dniowe okno obserwacji, kohorta 2021 wykazuje *najwyższy* wskaźnik wczesnych ponownych zakupów w całym zbiorze — niemal dwukrotność poziomu z 2018 roku. Jednocześnie dekompozycja przychodów ujawnia, że 63–70% kwartalnych przychodów w 2021 roku pochodzi od powracających klientów pozyskanych w latach wcześniejszych. Wzrost Kalifornii nie opiera się na kruchych jednorazowych zakupach. Jest napędzany dojrzewającą bazą klientów.

**Rzeczywista historia to nie spadek jakości, lecz rosnący biznes, którego najnowsi klienci nie mieli jeszcze czasu, żeby udowodnić swoją wartość.**

> Analiza ta pokazuje, że nawet wieloetapowe, dobrze ustrukturyzowane badanie może prowadzić do błędnych wniosków, gdy nie kontroluje się błędu systematycznego w pomiarze. Pełny obraz wymaga zrozumienia czasu, jakości klientów, wzorców akwizycji, zachowań retencyjnych — i różnicy między tym, co dane *pokazują*, a tym, co *oznaczają*.

---

## Problem: pojedyncza liczba, która nic nie mówi

### Punkt wyjścia: przychód według stanu

Każda analiza zaczyna się gdzieś. Naturalnym punktem wyjścia jest najbardziej widoczna metryka: łączny przychód w podziale na stany dostawy. Kalifornia prowadzi zdecydowanie — 451 451 $ przychodu. Nowy Jork na drugim miejscu z 312 377 $, Teksas z 164 949 $. Na dashboardzie wygląda to jak jasna odpowiedź na pytanie „Gdzie powinniśmy skoncentrować zasoby?"

Ale to jest właśnie **pułapka metryk próżności**. Pojedyncza zagregowana wartość składa cztery lata historii biznesowej w jedną liczbę. Nie powie nam, czy Kalifornia rośnie czy spada, czy klienci wracają, czy baza przychodowa jest strukturalnie zdrowa. Pokazuje jedynie wynik końcowy — nie to, jak rozgrywka przebiegała.

<img width="1011" height="408" alt="image" src="https://github.com/user-attachments/assets/873a5cdc-8298-4fdd-b361-92cc181643e7" />

---

## Pierwsza czerwona flaga: tajemniczy spadek przychodów

Logicznym kolejnym krokiem jest analiza wyników Kalifornii w czasie. Zestawienie rok do roku zdaje się ujawniać katastrofę: niemal 90-procentowy spadek przychodów między 2021 a 2022 rokiem — ze 148 729 $ do zaledwie 16 186 $.

**Rzetelna analiza wymaga sceptycyzmu, zanim zareagujemy.** Spadek tej skali, z roku na rok i bez zewnętrznego kontekstu, jest statystycznie nieprawdopodobny w funkcjonującym biznesie. Pytanie nie brzmi jedynie „co się stało?" — lecz „czy to jest realne, czy coś jest nie tak z danymi?"

Prosty rozkład na poziomie miesięcy natychmiast ujawnia prawdę: **zbiór danych za 2022 rok zawiera wyłącznie styczeń.** Pozorny krach nie jest porażką biznesową — to niekompletny zbiór danych porównywany z pełnym rokiem kalendarzowym. Jeden miesiąc przychodu niemal zawsze będzie wyglądał gorzej niż dwanaście.

<img width="1022" height="495" alt="image" src="https://github.com/user-attachments/assets/95790aec-74d3-4c2d-9cd6-950c52c8d48a" />

Ten moment ilustruje fundamentalną zasadę analityczną: **nigdy nie wyciągaj wniosków z liczb, których nie zwalidowałeś.** Błędny raport, który trafi do niewłaściwego odbiorcy, może uruchomić błędną alokację zasobów, fałszywy alarm lub nieuzasadnioną pewność siebie. Kompletność danych to nie detal techniczny — to ryzyko biznesowe.

> **Decyzja analityczna:** rok 2022 został wykluczony ze wszystkich analiz porównawczych. Jednak zamówienia ze stycznia 2022 pozostają w obliczeniach dotyczących klientów — klient pozyskany w grudniu 2021, który złożył ponowne zamówienie w styczniu 2022, musi być liczony jako klient powracający. Rozróżnienie między „wykluczyć z raportowania" a „wykluczyć z obliczeń" ma znaczenie.

---

## Głębsza analiza: co napędza wzrost

Po potwierdzeniu integralności danych analiza przechodzi do zrozumienia dynamiki wzrostu Kalifornii. Metryki miesiąc do miesiąca i rok do roku — przychód, liczba zamówień, unikalni klienci, sprzedane sztuki, średnia wartość zamówienia, głębokość rabatów — rysują obraz silnego wzrostu do końca 2021 roku.

Wrzesień 2021 pokazuje +71,85% wzrostu przychodu rok do roku, niemal podwojenie sprzedanych sztuk (+87%) i wzrost liczby unikalnych klientów o +58%. Listopad 2021 przynosi jeszcze bardziej wyraźne wyniki: +111% wzrostu przychodu, przy tej samej liczbie unikalnych klientów co rok wcześniej.

Według konwencjonalnych miar to wyniki godne nagłówka. Ale pojawia się kluczowe pytanie: **jakich klientów pozyskujemy w tych miesiącach wzrostu?**

Wolumen łatwo zmierzyć. Jakość jest trudniejsza — i znacznie ważniejsza. Biznes pozyskujący tysiąc niskouwartościowych, jednorazowych kupujących jest w fundamentalnie innej sytuacji niż biznes pozyskujący stu klientów o wysokiej wartości i powtarzalności zakupów, nawet jeśli krótkoterminowy przychód wygląda identycznie.

> **Kluczowa decyzja analityczna:** zamiast akceptować wzrost wolumenu jako sukces, analiza przechodzi na perspektywę jakości klientów. Pytanie zmienia się z „o ile urośliśmy?" na „z kim urośliśmy?" Ta zmiana perspektywy oddziela raportowanie opisowe od faktycznej analityki biznesowej.

---

## Segmentacja klientów: kto generuje realną wartość?

### Budowa modelu segmentacji

Aby wyjść poza przychód jako przybliżenie wartości, klienci zostali sklasyfikowani w czterech segmentach na podstawie dwóch obserwowalnych wymiarów: **łączny przychód historyczny** i **udokumentowana powtarzalność zakupów** (zamówienia > 1).

Próg przychodowy 1 000 $ wynika z empirycznego rozkładu przychodów klientów z Kalifornii (n = 565, po wykluczeniu 12 klientów pozyskanych wyłącznie w styczniu 2022): mediana wynosi ~390 $, a 75. percentyl ~1 050 $, co czyni 1 000 $ uzasadnionym przybliżeniem granicy górnego kwartyla.

| Segment | Definicja | Liczba | Przychód | % łącznego przychodu |
|---|---|---|---|---|
| `top_customer` | Kupujący wielokrotnie, przychód ≥ 1 000 | 120 (21%) | 256 291 $ | 57% |
| `risky_high_value` | Kupujący jednorazowo, przychód ≥ 1 000 | 39 (7%) | 72 972 $ | 16% |
| `loyal_low_value` | Kupujący wielokrotnie, przychód < 1 000 | 173 (31%) | 72 032 $ | 16% |
| `low_value` | Kupujący jednorazowo, przychód < 1 000 | 233 (41%) | 47 754 $ | 11% |

Top customers — 21% bazy klientów — odpowiadają za 57% łącznego przychodu Kalifornii. Ta koncentracja jest fundamentem analitycznym: jeśli pipeline segmentu top_customer wyschnie, przychód podąży za nim.

> **Nota o przejrzystości metryk:** popularna formuła CLV (średnia_wartość_zamówienia × częstotliwość_zakupów × czas_życia_w_miesiącach) algebraicznie upraszcza się do łącznego przychodu we wszystkich przypadkach. Użycie łącznego przychodu bezpośrednio jest prostsze i bardziej uczciwe — pozwala uniknąć wrażenia modelu predykcyjnego, gdy metryka jest czysto opisowa.

---

## Pozorny sygnał ostrzegawczy: skład segmentów w czasie

Zastosowanie modelu segmentacji do kohort akwizycyjnych w podziale na lata ujawnia to, co początkowo wygląda na najważniejsze odkrycie w tym zbiorze danych.

| Okres | Łącznie | Top | Ryzykowni | Lojalni | Niskiej wartości | Top % |
|--------|---------|-----|-----------|---------|------------------|-------|
| 2018 | 160 | 72 | 10 | 39 | 39 | 45,00% |
| 2019 | 147 | 59 | 17 | 25 | 46 | 40,14% |
| 2020 | 147 | 46 | 12 | 32 | 57 | 31,29% |
| 2021 | 111 | 6 | 25 | 14 | 66 | 5,40% |

Wzorzec jest dramatyczny: udział top_customer spada z 45% w 2018 do 5,40% w 2021 roku. Segment low_value całkowicie dominuje kohortę 2021.

<img width="1029" height="511" alt="image" src="https://github.com/user-attachments/assets/e9a66240-4027-46f2-805b-ec1c90e149e6" />

<img width="1152" height="616" alt="image" src="https://github.com/user-attachments/assets/816a5074-b2ec-4279-bff4-a7c28a2b94a3" />

**Instynktowny wniosek:** jakość akwizycji w Kalifornii się załamała. Pipeline klientów o wysokiej wartości wysycha. Przychód jest zagrożony.

**Ten wniosek wydaje się przekonujący. Jest również błędny.**

---

## Pułapka: tenure bias

### Dlaczego segmentacja jest myląca

Segmentacja przypisuje etykiety na podstawie *pełnej* historii zakupowej klienta — każdego zamówienia, jakie kiedykolwiek złożył, aż do grudnia 2021. To tworzy strukturalną przewagę starszych klientów:

- Klient pozyskany w **2018 roku** miał **~48 miesięcy** na akumulację przychodu i wykazanie powtarzalności zakupów
- Klient pozyskany w **Q4 2021** miał **~2 miesiące lub mniej**

Próg top_customer wymaga jednocześnie przychodu ≥ 1 000 ORAZ więcej niż jednego zamówienia. Klient z 2021 roku mógł złożyć zamówienie na 500 $ z pełnym zamiarem powrotu — ale dane po prostu nie sięgają wystarczająco daleko, żeby to zaobserwować. Zakwalifikowanie tego klienta jako „low_value" na podstawie niekompletnej obserwacji tworzy *artefakt pomiarowy*, który podszywa się pod wniosek biznesowy.

> **To jest tenure bias:** systematyczna błędna klasyfikacja nowszych klientów jako niskouwartościowych, spowodowana nierównymi oknami obserwacji — nie rzeczywistymi różnicami w zachowaniu klientów.

### Konsekwencje przeoczenia tego błędu

Jeśli ten błąd systematyczny nie zostanie wykryty, kaskada analityczna jest przewidywalna i szkodliwa:

1. **Niekompletne dane** → segmenty przechylają się w stronę low_value dla najnowszych kohort
2. **Przechylone segmenty** → analityk wnioskuje, że jakość akwizycji spada
3. **Fałszywy wniosek** → biznes przekierowuje zasoby na „naprawienie" akwizycji
4. **Błędna alokacja** → realne szanse (retencja, rozwój relacji z nowymi klientami) zostają pominięte

Droga od błędu pomiarowego do błędnej alokacji strategicznej jest krótka i realistyczna. To sprawia, że tenure bias to nie tylko kwestia statystyczna, ale realne ryzyko biznesowe.

---

## Trzy niezależne testy

### Test 1: dekompozycja przychodów — skąd faktycznie pochodzi wzrost?

Aby zrozumieć, czy wzrost w 2021 roku jest faktycznie kruchy, przychody kwartalne zostały rozłożone na dwa strumienie: przychód od **nowo pozyskanych klientów** (pierwsze zamówienie w danym kwartale) versus przychód od **klientów powracających** (pozyskanych w wcześniejszych okresach).

| kwartał | przychód_bieżący | przychód_poprzedni_rok | zmiana_% | przychód_nowi | przychód_powracający | nowi_% |
|---------|------------------|------------------------|----------|---------------|----------------------|--------|
| 2018-Q1 | 3 256,95 | NULL | NULL | 3 256,95 | 0,00 | 100,0 |
| 2018-Q2 | 20 083,21 | NULL | NULL | 20 083,21 | 0,00 | 100,0 |
| 2018-Q3 | 25 157,12 | NULL | NULL | 22 913,32 | 2 243,80 | 91,1 |
| 2018-Q4 | 22 805,19 | NULL | NULL | 19 741,56 | 3 063,63 | 86,6 |
| 2019-Q1 | 24 741,12 | 3 256,95 | 659,63 | 20 638,53 | 4 102,60 | 83,4 |
| 2019-Q2 | 22 395,39 | 20 083,21 | 11,51 | 18 002,50 | 4 392,89 | 80,4 |
| 2019-Q3 | 15 343,97 | 25 157,12 | -39,01 | 9 979,32 | 5 364,65 | 65,0 |
| 2019-Q4 | 30 826,62 | 22 805,19 | 35,18 | 24 445,34 | 6 381,28 | 79,3 |
| 2020-Q1 | 17 415,10 | 24 741,12 | -29,61 | 11 849,45 | 5 565,65 | 68,0 |
| 2020-Q2 | 27 129,42 | 22 395,39 | 21,14 | 7 271,37 | 19 858,05 | 26,8 |
| 2020-Q3 | 36 663,72 | 15 343,97 | 138,90 | 26 257,12 | 10 406,60 | 71,6 |
| 2020-Q4 | 40 716,83 | 30 826,62 | 32,08 | 23 077,68 | 17 639,15 | 56,7 |
| 2021-Q1 | 31 525,28 | 17 415,10 | 81,03 | 9 354,14 | 22 171,14 | 29,7 |
| 2021-Q2 | 26 714,29 | 27 129,42 | -1,53 | 6 444,80 | 20 269,49 | 24,1 |
| 2021-Q3 | 42 513,58 | 36 663,72 | 15,95 | 19 441,16 | 23 072,42 | 45,7 |
| 2021-Q4 | 47 976,29 | 40 716,83 | 17,83 | 17 754,29 | 30 222,00 | 37,0 |

<img width="1062" height="548" alt="image" src="https://github.com/user-attachments/assets/28172b34-5202-40e1-b44c-4741ec4ead28" />

Trend jest jednoznaczny. W 2018 roku niemal 100% przychodu pochodzi od nowych klientów — naturalnie, biznes dopiero startuje. Do Q1 2021 **70,3% przychodu pochodzi od klientów powracających.** W Q4 2021 klienci powracający generują 30 222 $ — więcej niż łączny kwartalny przychód w dowolnym kwartale 2018 roku.

**To bezpośrednio zaprzecza hipotezie o „kruchym wzroście".** Przychód Kalifornii w 2021 roku nie opiera się na jednorazowych zakupach niskouwartościowych nowicjuszy. Jest napędzany przez skumulowaną wartość klientów pozyskanych w poprzednich latach, którzy wracają. Biznes dojrzewa, nie słabnie.

### Test 2: retencja według segmentu — czy top customers faktycznie utrzymują się lepiej?

Wskaźniki retencji obliczono per zdarzenie zakupowe z korektą right-censoring — każde okno obserwacji (30, 90, 180 dni) uwzględnia wyłącznie zdarzenia zakupowe, dla których pełne okno mieści się w dostępnych danych. Zapobiega to karaniu zamówień z końca 2021 roku za niewystarczający czas obserwacji.

| Segment | Kwalifikujący się (180d) | Powrócili | Wskaźnik | Kwalifikujący się (90d) | Powrócili | Wskaźnik | Kwalifikujący się (30d) | Powrócili | Wskaźnik |
|---|---|---|---|---|---|---|---|---|---|
| `top_customer` | 264 | 56 | **21,21%** | 294 | 31 | **10,54%** | 313 | 7 | **2,24%** |
| `loyal_low_value` | 324 | 45 | **13,89%** | 362 | 28 | **7,73%** | 399 | 14 | **3,51%** |
| `risky_high_value` | 29 | 0 | 0,00% | 34 | 0 | 0,00% | 39 | 0 | 0,00% |
| `low_value` | 198 | 0 | 0,00% | 217 | 0 | 0,00% | 233 | 0 | 0,00% |

Wyniki ujawniają obraz bardziej złożony niż prosta hierarchia:

- W oknie **180-dniowym** top_customers utrzymują się 1,5× lepiej niż loyal_low_value (21,21% vs 13,89%)
- W oknie **90-dniowym** top_customers prowadzą 1,4× (10,54% vs 7,73%)
- W oknie **30-dniowym** wzorzec **się odwraca**: loyal_low_value utrzymują się lepiej (3,51% vs 2,24%)

To sugeruje różne kadencje zakupowe, nie prostą hierarchię „lepsi/gorsi". Klienci loyal_low_value dokonują częstszych, mniejszych zakupów — zachowanie szybkiego ponownego zamówienia. Top customers dokonują większych, bardziej przemyślanych zakupów w dłuższych odstępach. Oba wzorce reprezentują realną wartość biznesową, ale wymagają różnych strategii retencyjnych.

Zerowa retencja dla segmentów low_value i risky_high_value to tautologia definicyjna, nie wynik analityczny: oba segmenty są zdefiniowane jako kupujący jednorazowo (zamówienia = 1), więc z definicji nie mają kolejnego zamówienia.

### Test 3: wskaźnik ponownych zakupów kohortowych — test rozstrzygający

Zamiast klasyfikować klientów na podstawie pełnej historii, każda kohorta akwizycyjna otrzymuje to samo **90-dniowe okno** na wykazanie ponownych zakupów. Klient „powrócił", jeśli złożył jakiekolwiek kolejne zamówienie w Kalifornii w ciągu 90 dni od pierwszego zakupu. Uwzględniono wyłącznie klientów pozyskanych co najmniej 90 dni przed granicą zbioru danych (25.01.2022) — dlatego dla 2021 roku raportowanych jest 85 klientów, a nie 111 jak na wykresie 4.

| Rok akwizycji | Pozyskani klienci | Powrócili (180d) | Wskaźnik (180d) | Powrócili (90d) | Wskaźnik (90d) | Wykluczeni klienci |
|---|---|---|---|---|---|---|
| 2018 | 160 | 13 | 8,13% | 6 | **3,75%** | 0 |
| 2019 | 147 | 15 | 10,20% | 9 | **6,12%** | 0 |
| 2020 | 147 | 26 | 17,69% | 10 | **6,80%** | 0 |
| 2021 | 85 | | | 6 | **7,06%** | 26 |
| 2021 | 59 | 7 | 11,86% | | | 52 |

**Kohorta 2021 w oknie 90-dniowym ma najwyższy wskaźnik ponownych zakupów w całym zbiorze** — niemal dwukrotność poziomu bazowego z 2018 roku. Trend jest monotonicznie rosnący: 3,75% → 6,12% → 6,80% → 7,06%.

Ten wynik obala pozorny wniosek z analizy segmentacyjnej. Mniejsza liczba top_customers w 2021 roku nie jest sygnałem pogarszającej się jakości akwizycji. To artefakt pomiarowy wynikający z nierównych okien obserwacji. Przy równym czasie obserwacji klienci z 2021 roku wykazują *silniejsze* wczesne zaangażowanie niż jakakolwiek wcześniejsza kohorta.

Warto zwrócić uwagę na dodatkowy aspekt — kolejną pułapkę analityczną — mianowicie dwa osobne wiersze dla roku 2021. To rozróżnienie wynika z tego, że klienci kwalifikujący się w oknie 90-dniowym do końca zbioru danych stanowią inną kohortę niż ci, dla których dostępne jest 180-dniowe okno obserwacji.

---

## Wniosek końcowy: oddzielenie sygnału od artefaktu

Analiza zaczyna się od pojedynczej wartości przychodowej i metodycznie odsłania kolejne warstwy. Po drodze napotyka klasyczną pułapkę analityczną — i ją omija.

### Co jest realne

- **Kalifornia prowadzi w przychodach** (451 450 $), a jej wzrost od 2018 do 2021 roku jest autentyczny i konsekwentny
- **Top customers są nieproporcjonalnie wartościowi** — 21% klientów generuje 57% przychodu, z 1,4–1,5× wyższą retencją długoterminową
- **Biznes dojrzewa** — przychód od klientów powracających rośnie z 0% do 63–70% kwartalnego przychodu do 2021 roku, co jest strukturalnie pozytywne
- **Najnowsze kohorty wykazują rosnące zaangażowanie** — wskaźnik ponownych zakupów w oknie 90-dniowym podwaja się między 2018 a 2021 rokiem
- **Różne segmenty mają różne kadencje zakupowe** — klienci loyal_low_value kupują częściej w oknie 30-dniowym; top_customers utrzymują zaangażowanie w oknach 90–180-dniowych

### Co jest artefaktem

- **„Załamanie" akwizycji top_customer w 2021 roku** — tenure bias, nie realny spadek jakości. Nowsi klienci nie mieli wystarczająco dużo czasu, żeby przekroczyć progi przychodowe i zakupowe
- **Zmiana składu segmentów** — wizualnie dramatyczna na wykresach 3 i 4, ale oczekiwana przy nierównych oknach obserwacji
- **Jakakolwiek narracja „sygnału ostrzegawczego" sugerująca zagrożenie przychodów Kalifornii** — przekonująca na pierwszy rzut oka, ale empirycznie obalona przez kontrolowaną analizę kohortową

### Implikacje strategiczne

- **Pielęgnuj kohorty z 2021 roku** — wykazują najwyższy wczesny wskaźnik ponownych zakupów. Komunikacja posprzedażowa, programy lojalnościowe i kampanie reaktywacyjne powinny celować w tych klientów, zanim staną się nieaktywni
- **Monitoruj 90-dniowy wskaźnik ponownych zakupów jako wskaźnik wyprzedzający** — jest mniej obciążony błędem systematycznym niż skład segmentów i bardziej praktyczny niż łączne przychody z pełnej historii
- **Traktuj bazę klientów powracających jako aktywo** — 63% przychodu w Q4 2021 pochodzi od klientów powracających. Ta baza jest silnikiem przychodowym; jej ochrona ma większe znaczenie niż optymalizacja nowej akwizycji

> *Kalifornia prowadzi w przychodach. Jej najnowsi klienci wykazują najsilniejsze wczesne zaangażowanie w całym zbiorze danych. Prawdziwe ryzyko nie polega na tym, że biznes pozyskuje niewłaściwych klientów — lecz na tym, że może nie utrzymać właściwych.*

---

## Dlaczego to ma znaczenie: sposób myślenia analityka

Ten projekt demonstruje coś ważniejszego niż biegłość w SQL: **gotowość do obalenia własnej hipotezy.**

Analiza segmentacyjna buduje spójny, dobrze poparty argument, że jakość akwizycji w Kalifornii spada. Wykresy są przekonujące. Tabele się zgadzają. Narracja ma intuicyjny sens. Przeszłaby większość przeglądów.

Jest również błędna.

Błąd nie tkwi w SQL. Zapytania zwracają poprawne wyniki. Błąd tkwi w ramie analitycznej — zastosowaniu retrospektywnej segmentacji (która nagradza staż) do pytania o zmianę w czasie (które wymaga kontrolowanego porównania). Wychwycenie tego wymaga wyjścia poza analizę, zakwestionowania metodologii i zbudowania niezależnego testu zdolnego sfalsyfikować wniosek.

Praca techniczna — Window Functions, CTEs, right-censoring, analiza kohortowa — służy temu sposobowi myślenia. Narzędzia mają znaczenie. Ale wiedza o tym, kiedy narzędzia Cię zwodzą, ma znaczenie większe.

---

*Piotr Rzepka · Portfolio Analityczne SQL — E-Commerce · Baza `supersales` · MySQL 8.0+*
