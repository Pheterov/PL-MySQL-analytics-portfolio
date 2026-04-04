Projekt: Portfolio Analityczne SQL — E-commerce
🛠️ Baza danych: supersales — zmodyfikowana przez KajoData, MySQL 8.0+
👤 Autor: Piotr Rzepka
📝 Opis: Portfolio analityczne SQL — e-commerce

																					"Historia przychodów Kalifornii" 

/*

Projekt powstał jako ćwiczenie z analizy danych, z wsparciem AI na etapie code review 
i iteracyjnych poprawek. Metodologia analityczna (kontrola tenure bias, 
right-censoring, dekompozycja przychodów) została wypracowana w ramach mentoringu. 
Cały kod SQL jest mojego autorstwa, napisany i zweryfikowany na działającej bazie danych.

Analiza SQL danych e-commerce z lat 2018–2022 ujawnia, że Kalifornia prowadzi w łącznych przychodach.
Wstępna segmentacja sugerowała spadek jakości akwizycji od 2021 roku, jednak analiza kontrolowana
kohortowo wykazała, że był to artefakt tenure bias — najnowsze kohorty w rzeczywistości wykazują
rosnące wskaźniki wczesnych ponownych zakupów. Wzrost przychodów w 2021 roku był napędzany przez
dojrzewającą bazę klientów powracających.
*/

/*================================================================================================================================================================================================
📋 Założenia dotyczące danych i konwencje stosowane w całej analizie:

   1. COALESCE(p.product_price, 0) — wartości NULL cen produktów traktowane są jako zero (darmowe produkty lub brakujące dane).
      COALESCE(op.position_discount, 0) — wartości NULL rabatów traktowane są jako brak zastosowanego rabatu.
      Są to świadome założenia biznesowe. Jeśli NULL oznacza w rzeczywistości „wartość nieznana", przychody
      mogą być zawyżone. Powinno to zostać zwalidowane z właścicielem danych przed użyciem produkcyjnym.

   2. Wartości delivery_state są traktowane jako czyste i jednolicie sformatowane (np. brak zapisu małymi literami
      'california' ani końcowych spacji). Wstępna weryfikacja SELECT DISTINCT delivery_state została wykonana,
      aby to potwierdzić.

   3. Formuła przychodu: item_quantity × product_price × (1 − position_discount).
      Reprezentuje przychód netto po rabatach na poziomie pozycji, przed podatkiem i kosztami wysyłki.
================================================================================================================================================================================================*/
	
/*================================================================================================================================================================================================
1️⃣ Przychód i liczba zamówień według stanu dostawy
================================================================================================================================================================================================*/
	   
SELECT
	o.delivery_state
	,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*
		(1-COALESCE(op.position_discount,0))), 2) 																							revenue
	,COUNT(DISTINCT op.order_id)																											orders_cnt
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
GROUP BY o.delivery_state
ORDER BY revenue DESC;

/*================================================================================================================================================================================================	   
Fragment wyniku zapytania:

| delivery_state | revenue    | orders_cnt  |
|----------------|------------|-------------|
| California 	 | 451 450,55 | 	  1 021 |
| New York		 | 312 376,98 | 		562 |
| Texas			 | 164 948,68 | 		487 |

Ta podstawowa metryka tak naprawdę nic nam nie mówi... Czy na podstawie takiego raportu możemy podjąć świadomą i trafną decyzję?
Zidentyfikowaliśmy jedynie, który region jest najbardziej dochodowy, ale spróbujmy pójść głębiej i krok po kroku ustalić — dlaczego.
Co dalej? Dobrze byłoby zobaczyć wyniki w czasie.
================================================================================================================================================================================================*/

/*================================================================================================================================================================================================
2️⃣ Wyniki rok do roku (YoY)
================================================================================================================================================================================================*/

SELECT
	EXTRACT(YEAR FROM o.order_date)																											year
	,o.delivery_state
	,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*
		(1-COALESCE(op.position_discount,0))), 2) 																							revenue
	,COUNT(DISTINCT op.order_id)																											orders_cnt
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
WHERE o.delivery_state='California'
GROUP BY YEAR,o.delivery_state
ORDER BY year DESC;

/*================================================================================================================================================================================================	
Fragment wyniku zapytania:

| year | delivery_state | revenue    | orders_cnt |
|------|----------------|------------|------------|
| 2022 | California     |  16 186,48 |         37 |
| 2021 | California     | 148 729,44 |        336 |
| 2020 | California     | 121 925,07 |        279 |
| 2019 | California     |  93 307,09 |        198 |
| 2018 | California     |  71 302,47 |        171 |

Wynik jest podejrzany... natychmiast podnosi czerwoną flagę.
Między 2018 a 2021 Kalifornia radziła sobie świetnie, a potem w 2022... nagły spadek przychodów o ~90%.
Tak drastyczna zmiana jest wysoce nieprawdopodobna z perspektywy biznesowej.

TO ZAPYTANIE JEST KLASYCZNYM PRZYKŁADEM TEGO, JAK MYLĄCE WNIOSKI MOGĄ WYNIKAĆ Z MYŚLENIA TYPU „po prostu weź średnią".

📝 Co zamierzam zrobić dalej:
- zwalidować kompletność danych i dodać kolumnę miesięcy do wyniku
- ponownie sprawdzić logikę agregacji
- dostosować filtrowanie, aby porównać z innymi regionami
================================================================================================================================================================================================*/

/*================================================================================================================================================================================================
2️⃣.1️⃣ Badanie czerwonej flagi w danych YoY
================================================================================================================================================================================================*/
	
SELECT
	EXTRACT(YEAR FROM o.order_date)																											year
	,EXTRACT(MONTH FROM o.order_date)																										month
	,o.delivery_state
	,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*
		(1-COALESCE(op.position_discount,0))), 2) 																							revenue
	,COUNT(DISTINCT op.order_id)																											orders_cnt
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2022
GROUP BY year,month,o.delivery_state
ORDER BY year DESC,month DESC, revenue DESC;

/*================================================================================================================================================================================================
Fragment wyniku zapytania:

| year | month | delivery_state | revenue    | orders_cnt |
|------|-------|----------------|------------|------------|
| 2022 |     1 | California     | 16 186,48  |         37 |
| 2022 |     1 | New York       |  5 757,49  |         19 |
| 2022 |     1 | Kentucky       |  4 113,58  |          4 |
| 2022 |     1 | Illinois       |  3 730,73  |         10 |
| 2022 |     1 | Michigan       |  3 663,71  |          5 |

Zgodnie z oczekiwaniami dane potwierdzają, że rok 2022 zawiera jedynie styczeń.
To wyjaśnia pozorny spadek przychodów YoY i wskazuje, że problem dotyczy kompletności danych, a nie faktycznych wyników biznesowych.
Możemy kontynuować pracę, koncentrując się na Kalifornii.
================================================================================================================================================================================================*/

/*================================================================================================================================================================================================
3️⃣ Wyniki Kalifornii miesiąc do miesiąca (MoM) — podstawowy wgląd
================================================================================================================================================================================================*/

SELECT
    EXTRACT(YEAR FROM o.order_date)                                                                         								year
    ,EXTRACT(MONTH FROM o.order_date)                                                                       								month
    ,o.delivery_state                                                                                        								delivery_state
    ,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*
		(1-COALESCE(op.position_discount,0))), 2) 																							revenue
    ,COUNT(DISTINCT op.order_id)                                                                            							    orders_cnt
    ,COUNT(DISTINCT o.customer_id)                                                                          								unique_customers
    ,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*
		(1-COALESCE(op.position_discount,0))) /
    COUNT(DISTINCT o.order_id), 2)                                                                         									aov
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
WHERE o.delivery_state = 'California'
GROUP BY year, month, o.delivery_state
-- Uwaga: o.delivery_state jest celowo uwzględnione w GROUP BY, aby umożliwić
-- potencjalne rozszerzenie tego zapytania na wiele stanów w przyszłych krokach analizy
ORDER BY year DESC, month DESC, revenue DESC;

/*================================================================================================================================================================================================
Fragment wyniku zapytania:

| year | month | delivery_state | revenue	 | orders_cnt | unique_customers | aov	  |
|------|-------|----------------|------------|------------|------------------|--------|
| 2022 |     1 | California     |  16 186,48 |         37 |               35 | 437,47 |
| 2021 |    12 | California     |  13 860,23 |         53 |               49 | 261,51 |
| 2021 |    11 | California     |  18 346,94 |         26 |               26 | 705,65 |
| 2021 |    10 | California     |  15 769,12 |         40 |               40 | 394,23 |
| 2021 |     9 | California     |  20 248,41 |         32 |               30 | 632,76 |

Wykorzystaliśmy trendy miesiąc do miesiąca, aby potwierdzić kompletność danych za każdy wcześniejszy miesiąc.
To dobry moment, żeby się zatrzymać i zdefiniować, co właściwie chcemy mierzyć i jak chcemy do tego podejść:
	- uwzględnianie każdej warianty metryki może generować szum zamiast wglądu
	- metryki powinny być logicznie spójne i łatwe do interpretacji — wrzucanie wszystkiego do jednej tabeli nie jest właściwym podejściem
	- struktura będzie ewoluować — dodawanie i usuwanie kolumn jest częścią procesu analitycznego
	- celem nie jest natychmiastowe przedstawienie ostatecznej odpowiedzi, lecz jasne pokazanie ścieżki rozumowania, która do niej prowadzi

Następny krok: metryki rok do roku (YoY)
================================================================================================================================================================================================*/

/*================================================================================================================================================================================================
4️⃣ Analiza rok do roku (YoY)
================================================================================================================================================================================================*/

WITH base_metrics AS 
(
SELECT
    EXTRACT(YEAR FROM o.order_date)                                                                         								year
    ,EXTRACT(MONTH FROM o.order_date)                                                                       								month
    ,o.delivery_state                                                                                        								delivery_state
    ,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*
		(1 - COALESCE(op.position_discount,0))), 2) 																						revenue
    ,COUNT(DISTINCT op.order_id)                                                                             								orders_cnt
    ,COUNT(DISTINCT o.customer_id)                                                                          								unique_customers
    ,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*
		(1-COALESCE(op.position_discount,0))) /
           COUNT(DISTINCT o.order_id), 2)                                                                   								aov
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
WHERE o.delivery_state = 'California'
GROUP BY year, month, o.delivery_state
ORDER BY year DESC, month DESC, revenue DESC
)
SELECT
	delivery_state
    ,year
    ,month
    ,revenue                                                                                               									current_year_revenue
    ,LAG(revenue) OVER(
		PARTITION BY month 
		ORDER BY year)                                   																					last_year_revenue
    ,orders_cnt
    ,LAG(orders_cnt) OVER(
		PARTITION BY month
		ORDER BY year)                                   																					last_year_orders_cnt
    ,unique_customers
    ,LAG(unique_customers) OVER(
		PARTITION BY month 
		ORDER BY year)																                                   						last_year_unique_customers
    ,aov
    ,LAG(aov) OVER(
		PARTITION BY month
		ORDER BY year)                                   																					last_year_aov
FROM base_metrics
ORDER BY year DESC, month DESC;

/*================================================================================================================================================================================================
Fragment wyniku zapytania:

| delivery_state | year | month | current_year_revenue | last_year_revenue | orders_cnt | last_year_orders_cnt | unique_customers | last_year_unique_customers |   aov  | last_year_aov |
|----------------|------|-------|----------------------|-------------------|------------|----------------------|------------------|----------------------------|--------|---------------|
| California     | 2022 |     1 |            16 186,48 |         19 957,45 |         37 |                   33 |               35 |                         33 | 437,47 |        604,77 |
| California     | 2021 |    12 |            13 860,23 |         19 555,03 |         53 |                   45 |               49 |                         45 | 261,51 |        434,56 |
| California     | 2021 |    11 |            18 346,94 |          8 693,27 |         26 |                   28 |               26 |                         26 | 705,65 |        310,47 |
| California     | 2021 |    10 |            15 769,12 |         12 468,53 |         40 |                   33 |               40 |                         33 | 394,23 |        377,83 |
| California     | 2021 |     9 |            20 248,41 |         11 782,73 |         32 |                   19 |               30 |                         19 | 632,76 |        620,14 |

📝 Uwagi i refleksje
   Tabela jest dość szeroka, głównie przez rozwlekłe nazwy kolumn. Ponieważ na tym etapie służy celom analitycznym wewnętrznym, możemy ją uprościć w kolejnych krokach.
   Możemy też zacząć oceniać, które metryki są naprawdę przydatne, a które mogą być zbędne. Na tym etapie delivery_state nie jest już potrzebne, ponieważ analiza koncentruje się wyłącznie na Kalifornii.

   Następny krok: zidentyfikować metryki, które faktycznie wyjaśniają dynamikę przychodów.
================================================================================================================================================================================================*/

/*================================================================================================================================================================================================
4️⃣.1️⃣ Obliczenia YoY, decyzje o kolumnach, optymalizacja nazw kolumn, głębokość rabatów, optymalizacja kodu
================================================================================================================================================================================================*/

WITH base_metrics AS 
(
-- CTE 1: Agregacja miesięczna dla Kalifornii
-- Obliczenie przychodu, zamówień, unikalnych klientów, sprzedanych sztuk, AOV, głębokości rabatów
SELECT
    EXTRACT(YEAR FROM o.order_date)																											year
    ,EXTRACT(MONTH FROM o.order_date)																										month
    ,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*
		(1-COALESCE(op.position_discount,0))),2)																							revenue           -- łączny przychód
    ,COUNT(DISTINCT op.order_id)																											orders_cnt        -- łączna liczba zamówień
    ,COUNT(DISTINCT o.customer_id)																											unique_customers  -- unikalni klienci
    ,SUM(op.item_quantity)																													items_sold        -- łączna liczba sprzedanych sztuk
    ,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*
		(1-COALESCE(op.position_discount,0)))/
        NULLIF(COUNT(DISTINCT op.order_id),0),2)																							aov               -- średnia wartość zamówienia
    ,ROUND(SUM(op.item_quantity*COALESCE(p.product_price,0)*COALESCE(op.position_discount,0)) /
        NULLIF(SUM(op.item_quantity*COALESCE(p.product_price,0)),0)*100,2)																	discount_depth    -- średnia ważona przychodem stopa rabatowa (łączna wartość rabatów / łączny przychód przed rabatem)
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
WHERE o.delivery_state = 'California'
GROUP BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
), materialized AS
(
-- CTE 2: Materializacja base_metrics w celu uniknięcia problemów z rozwiązywaniem aliasów w MySQL 8.0
SELECT *
FROM base_metrics
), yoy_metrics AS
(
-- CTE 3: Porównanie rok do roku (YoY)
-- Dodanie wartości z poprzedniego roku dla każdego miesiąca za pomocą Window Functions
SELECT
    year
    ,month
    ,revenue																																cyr_rev      -- przychód bieżącego roku
    ,LAG(revenue) OVER(
		PARTITION BY month
		ORDER BY year)																														lyr_rev      -- przychód poprzedniego roku
    ,orders_cnt																																orders_cnt   -- zamówienia bieżącego roku
    ,LAG(orders_cnt) OVER(
		PARTITION BY month
		ORDER BY year)																														lyr_orders   -- zamówienia poprzedniego roku
    ,unique_customers																														uniq_cstmr   -- klienci bieżącego roku
    ,LAG(unique_customers) OVER(
		PARTITION BY month
		ORDER BY year)																														lyr_uniq     -- klienci poprzedniego roku
    ,items_sold																																items_sold   -- sztuki bieżącego roku
    ,LAG(items_sold) OVER(
		PARTITION BY month
		ORDER BY year)																														lyr_items    -- sztuki poprzedniego roku
    ,aov																																	aov          -- AOV bieżącego roku
    ,LAG(aov) OVER(
		PARTITION BY month 
		ORDER BY year)																														lyr_aov      -- AOV poprzedniego roku
    ,discount_depth																															d_depth      -- głębokość rabatów bieżącego roku
    ,LAG(discount_depth) OVER(
		PARTITION BY month
		ORDER BY year)																														lyr_d_depth  -- głębokość rabatów poprzedniego roku
FROM materialized
)
SELECT
-- Końcowy SELECT: różnice YoY i zmiany procentowe dla wszystkich metryk
    year
    ,month
    ,cyr_rev
    ,lyr_rev
    ,cyr_rev-lyr_rev																														rev_diff          -- różnica przychodu
    ,ROUND((cyr_rev-lyr_rev) /
		NULLIF(lyr_rev,0)*100,2)																											rev_pct_diff      -- zmiana % przychodu
    ,orders_cnt
    ,lyr_orders
    ,orders_cnt-lyr_orders																													ord_diff          -- różnica zamówień
    ,ROUND((orders_cnt-lyr_orders) /
		NULLIF(lyr_orders,0)*100,2)																											ord_pct_diff      -- zmiana % zamówień
    ,uniq_cstmr
    ,lyr_uniq
    ,uniq_cstmr-lyr_uniq																													cstmr_diff        -- różnica klientów
    ,ROUND((uniq_cstmr-lyr_uniq) /
		NULLIF(lyr_uniq,0)*100,2)																											cstmr_pct_diff    -- zmiana % klientów
    ,items_sold
    ,lyr_items
    ,items_sold-lyr_items																													items_diff        -- różnica sztuk
    ,ROUND((items_sold-lyr_items) /
		NULLIF(lyr_items,0)*100,2)																											items_pct_diff    -- zmiana % sztuk
    ,aov
    ,lyr_aov
    ,aov-lyr_aov																															aov_change        -- różnica AOV
    ,ROUND((aov-lyr_aov) /
		NULLIF(lyr_aov,0)*100,2)																											aov_pct_change    -- zmiana % AOV
    ,d_depth
    ,lyr_d_depth
    ,d_depth-lyr_d_depth																													d_depth_diff      -- różnica głębokości rabatów
    ,ROUND((d_depth-lyr_d_depth) /
		NULLIF(lyr_d_depth,0)*100,2)																										d_depth_pct_change -- zmiana % głębokości rabatów
FROM yoy_metrics
ORDER BY year DESC, month DESC;

/*================================================================================================================================================================================================
Fragment wyniku zapytania:
-- Wynik przedstawiony w trzech pogrupowanych sekcjach dla czytelności. Wszystkie wiersze współdzielą te same klucze year/month.

-- Przychód i zamówienia
| year | month |   cyr_rev |   lyr_rev |   rev_diff | rev_pct_diff | orders_cnt | lyr_orders | ord_diff | ord_pct_diff |
|------|-------|-----------|-----------|------------|--------------|------------|------------|----------|--------------|
| 2022 |     1 | 16 186,48 | 19 957,45 | -3 770,97  |       -18,90 |         37 |         33 |        4 |        12,12 |
| 2021 |    12 | 13 860,23 | 19 555,03 | -5 694,80  |       -29,12 |         53 |         45 |        8 |        17,78 |
| 2021 |    11 | 18 346,94 |  8 693,27 |  9 653,67  |       111,05 |         26 |         28 |       -2 |        -7,14 |
| 2021 |    10 | 15 769,12 | 12 468,53 |  3 300,59  |        26,47 |         40 |         33 |        7 |        21,21 |
| 2021 |     9 | 20 248,41 | 11 782,73 |  8 465,68  |        71,85 |         32 |         19 |       13 |        68,42 |

-- Klienci i sztuki
| year | month | uniq_cstmr | lyr_uniq | cstmr_diff | cstmr_pct_diff | items_sold | lyr_items | items_diff | items_pct_diff |
|------|-------|------------|----------|------------|----------------|------------|-----------|------------|----------------|
| 2022 |     1 |         35 |       33 |          2 |           6,06 |        300 |       327 |        -27 |          -8,26 |
| 2021 |    12 |         49 |       45 |          4 |           8,89 |        336 |       312 |         24 |           7,69 |
| 2021 |    11 |         26 |       26 |          0 |           0,00 |        239 |       199 |         40 |          20,10 |
| 2021 |    10 |         40 |       33 |          7 |          21,21 |        329 |       230 |         99 |          43,04 |
| 2021 |     9 |         30 |       19 |         11 |          57,89 |        283 |       151 |        132 |          87,42 |

-- AOV i głębokość rabatów
| year | month |    aov |  lyr_aov | aov_change | aov_pct_change | d_depth | lyr_d_depth | d_depth_diff | d_depth_pct_change |
|------|-------|--------|----------|------------|----------------|---------|-------------|--------------|--------------------|
| 2022 |     1 | 437,47 |   604,77 |    -167,30 |         -27,66 |   13,73 |       15,21 |        -1,48 |              -9,73 |
| 2021 |    12 | 261,51 |   434,56 |    -173,05 |         -39,82 |   12,32 |        8,93 |         3,39 |              37,96 |
| 2021 |    11 | 705,65 |   310,47 |     395,18 |         127,28 |   11,85 |        8,96 |         2,89 |              32,25 |
| 2021 |    10 | 394,23 |   377,83 |      16,40 |           4,34 |   13,95 |       11,29 |         2,66 |              23,56 |
| 2021 |     9 | 632,76 |   620,14 |      12,62 |           2,04 |   11,58 |       17,62 |        -6,04 |             -34,28 |

Te tabele służą nam w przyszłych obliczeniach — nie będziemy ich raportować w obecnej formie.

Liczba kolumn może na pierwszy rzut oka przytłaczać. Dlaczego więc strukturyzujemy to w ten sposób,
skoro wcześniej mówiliśmy o redukcji ilości danych na rzecz łatwiejszego podejmowania decyzji zamiast generowania szumu?

Bo metryki bez kontekstu są mylące — co pokazaliśmy już w pierwszym zapytaniu tej prezentacji.
Porównanie pojedynczej metryki często wymaga spojrzenia na kilka powiązanych wartości.

Zmiana procentowa typu -5% sama w sobie niewiele znaczy. Czy oznacza spadek z 1 000 klientów do 950, czy z 20 klientów do 19?
Wpływ biznesowy w tych dwóch scenariuszach jest zupełnie inny. To samo dotyczy wartości bezwzględnych — utrata 10 klientów
może być nieistotna w skali, albo krytyczna, jeśli baza jest mała.

Ta tabela jest celowo zaprojektowana tak, aby zachować ten kontekst. Pokazując stan bieżący i poprzedni oraz
zarówno wartości bezwzględne, jak i ich zmiany (liczbowe i procentowe), możemy właściwie ocenić znaczenie
każdego ruchu zamiast reagować na odizolowane liczby.

Oczywiście to tylko część historii.

Z perspektywy biznesowej nie wszyscy klienci są równi. Utrata jednego klienta o wysokiej wartości i powtarzalności
zakupów może boleć znacznie bardziej niż utrata kilku jednorazowych kupujących o niskiej wartości.

Dokładnie w tym kierunku pójdziemy dalej.

Na marginesie — rzeczy warte uwagi wyłącznie z tego krótkiego fragmentu:

- W przypadku września wzrost przychodów można skorelować ze wzrostem bazy klientów w porównaniu z rokiem poprzednim.
  +71% przychodu, +68% zamówień, +57% klientów, niemal podwojone sprzedane sztuki. Sugeruje to, że wzrost
  był napędzany wolumenem, a nie zmianami w cenach czy zachowaniach klientów.

- Natomiast listopad 2021 to szczególnie interesujący przypadek.
  Taka sama liczba klientów, nieco mniej zamówień, ale przychód ponad podwojony (+111%) — silny kandydat do głębszej analizy.

Mimo że listopad 2021 prezentuje interesującą anomalię, nie wnosi bezpośrednio do wyjaśnienia ogólnych wyników Kalifornii.
   Jest więc celowo wykluczony z głębszej analizy na tym etapie i oznaczony jako potencjalna analiza uzupełniająca.

   Zanim przejdziemy dalej, warto zauważyć, że anomalia tej skali (+111% YoY przy mniejszej liczbie zamówień)
   może być spowodowana pojedynczym zamówieniem odstającym. Aby to wykluczyć, należy sprawdzić rozkład wartości
   zamówień w tym miesiącu (min, max, mediana, odchylenie standardowe). Jeśli jedno zamówienie odpowiada za
   nieproporcjonalny udział przychodu, wskaźnik wzrostu jest mylący. Ta walidacja jest odroczona, ale rekomendowana.

Uwagi i refleksje
   Obecnie wszystkie nasze działania odbywają się na poziomie stanu, ale w miarę postępu będziemy analizować je bardziej szczegółowo.
   Odpowiedzi nie leżą na wierzchu — musimy stale podejmować decyzje, które kolumny dodać lub usunąć, dostosować, zmienić granularność.
================================================================================================================================================================================================*/

/*================================================================================================================================================================================================
5️⃣ Segmentacja klientów według historycznego przychodu i powtarzalności zakupów
Cel: Sklasyfikowanie każdego klienta do segmentu biznesowego na podstawie łącznego historycznego
         przychodu i udokumentowanej powtarzalności zakupów.
Kontekst: Nie wszyscy klienci są równi. To zapytanie identyfikuje, kto generuje realną wartość,
            łącząc skumulowany wydatek z zaobserwowaną lojalnością (kupujący wielokrotnie vs jednorazowo).
            Segmenty: top_customer, risky_high_value, loyal_low_value, low_value.
 
Klienci zostali sklasyfikowani w czterech segmentach na podstawie powtarzalności zakupów i łącznego historycznego przychodu.
Próg przychodowy 1 000 wynika z empirycznego rozkładu łącznego przychodu klientów z Kalifornii
(n = 565, po wykluczeniu klientów pozyskanych wyłącznie w 2022): mediana wynosi ~390, a 75. percentyl ~1 050,
co czyni 1 000 uzasadnionym przybliżeniem granicy górnego kwartyla.
 
Decyzje dotyczące zakresu:
    1. Rok 2022 jest wykluczony: dostępne są jedynie dane ze stycznia, co daje tym klientom niemal zerowy czas
       na wykazanie powtarzalności zakupów. Ich uwzględnienie sztucznie zawyżyłoby segment low_value.
       Jednak zamówienia z 2022 SĄ uwzględnione w podstawowych obliczeniach przychodu/powtarzalności — klient pozyskany
       w 2021, który zamówił ponownie w styczniu 2022, jest poprawnie liczony jako kupujący wielokrotnie.
 
    2. Wszystkie metryki wykorzystują wyłącznie zamówienia dostarczone do Kalifornii. Niemal wszyscy klienci z Kalifornii
       (574 z 577) zamawiali również do innych stanów. Ich profil ograniczony do Kalifornii może zaniżać
       rzeczywiste zaangażowanie. Jest to świadoma decyzja o zakresie, udokumentowana dla przejrzystości.
 
    3. Metryka segmentacji to łączny historyczny przychód — nie „model CLV". Popularna formuła CLV
       (średnia_wartość_zamówienia × częstotliwość_zakupów × czas_życia_w_miesiącach) algebraicznie upraszcza się
       do łącznego przychodu we wszystkich przypadkach, więc użycie łącznego przychodu bezpośrednio jest prostsze
       i bardziej uczciwe. To podejście jest obciążone na korzyść starszych klientów; zapytanie 5️⃣.4️⃣ kontroluje ten efekt.
================================================================================================================================================================================================*/
 
WITH customer_metrics AS 
(
-- Wszystkie zamówienia z Kalifornii 2018–2022 uwzględnione dla dokładnej klasyfikacji przychodu i powtarzalności.
-- Klient pozyskany w grudniu 2021, który zamówił ponownie w styczniu 2022, musi być liczony jako kupujący wielokrotnie.
SELECT
    o.customer_id                                                                   customer_id
    ,COUNT(DISTINCT o.order_id)                                                     orders_cnt
    ,SUM(op.item_quantity*COALESCE(p.product_price, 0)
        *(1-COALESCE(op.position_discount, 0)))                                     total_revenue
    ,MIN(o.order_date)                                                              first_order_date
    ,MAX(o.order_date)                                                              last_order_date
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
WHERE o.delivery_state = 'California'
GROUP BY o.customer_id
-- Wykluczenie klientów pozyskanych w 2022 (niekompletny okres)
HAVING EXTRACT(YEAR FROM MIN(o.order_date)) < 2022
)
SELECT
    customer_id                                                                     customer_id
    ,orders_cnt                                                                     orders_cnt
    ,ROUND(total_revenue, 2)                                                        historical_revenue
    ,ROUND(total_revenue / NULLIF(orders_cnt, 0), 2)                                avg_order_value
    ,CASE WHEN orders_cnt > 1 THEN 1 ELSE 0 END                                    is_repeat_customer
    ,CASE
        WHEN orders_cnt > 1 AND total_revenue >= 1000 THEN 'top_customer'
        WHEN orders_cnt = 1 AND total_revenue >= 1000 THEN 'risky_high_value'
        WHEN orders_cnt > 1                            THEN 'loyal_low_value'
        ELSE 'low_value'
    END                                                                             customer_segment
FROM customer_metrics
ORDER BY total_revenue DESC;
 
/*================================================================================================================================================================================================
Wynik zapytania — podsumowanie segmentów:
 
| customer_segment | customers_cnt | total_revenue | avg_revenue | avg_orders | min_revenue | max_revenue |
|------------------|---------------|---------------|-------------|------------|-------------|-------------|
| top_customer     |           120 |    256 290,76 |    2 135,76 |       2,67 |    1 029,17 |    8 349,89 |
| risky_high_value |            39 |     72 972,35 |    1 871,09 |       1,00 |    1 011,70 |    4 006,21 |
| loyal_low_value  |           173 |     72 032,08 |      416,37 |       2,40 |       20,02 |      996,58 |
| low_value        |           233 |     47 754,43 |      204,95 |       1,00 |        3,98 |      976,83 |
 
📝 Uwagi i refleksje
   Po wykluczeniu 12 klientów pozyskanych wyłącznie w styczniu 2022 mamy 565 klientów z Kalifornii.
 
   top_customer (120, 21%): kupujący wielokrotnie z przychodem >= 1 000. Odpowiadają za 57% łącznego
   przychodu Kalifornii, stanowiąc jedynie 21% bazy klientów.
 
   risky_high_value (39, 7%): kupujący jednorazowo z przychodem >= 1 000. Wysoki wydatek, ale brak
   udowodnionej lojalności — strukturalnie kruchy segment.
 
   loyal_low_value (173, 31%): kupujący wielokrotnie z przychodem < 1 000. Konsekwentne zaangażowanie,
   ale niższy indywidualny wkład.
 
   low_value (233, 41%): kupujący jednorazowo z przychodem < 1 000. Największy segment liczebnie,
   najmniejszy pod względem wkładu przychodowego.
 
   Ta segmentacja ma znane ograniczenie: jest obciążona na korzyść starszych klientów, którzy mieli więcej
   czasu na akumulację przychodu i ponownych zakupów. Klient pozyskany w 2018 miał ~4 lata na budowanie
   historii, podczas gdy klient pozyskany pod koniec 2021 miał zaledwie kilka miesięcy. Zapytanie 5️⃣.4️⃣
   adresuje to bezpośrednio za pomocą analizy wskaźnika ponownych zakupów kontrolowanej kohortowo.
================================================================================================================================================================================================*/
 
/*================================================================================================================================================================================================
5️⃣.1️⃣ Rozkład segmentów klientów według kwartału akwizycji
Cel: Zrozumienie, jakiego rodzaju klienci byli pozyskiwani w poszczególnych kwartałach.
Kontekst: Segmenty oparte są na pełnej historii klienta (zapytanie 5️⃣).
            Pokazuje to, czy klienci o wysokiej wartości byli pozyskiwani w okresach wzrostu.
            Granularność kwartalna zapewnia bardziej stabilne liczebności niż miesięczna,
            jednocześnie umożliwiając sensowne porównanie YoY.
 
⚠️ Rok 2022 wykluczony — klienci pozyskani w styczniu 2022 mieli niemal zerową szansę na ponowny zakup.
   Zastrzeżenie dotyczące tenure bias: patrz zapytanie 5️⃣.4️⃣ dla porównania kontrolowanego.
================================================================================================================================================================================================*/
 
WITH customer_metrics AS 
(
SELECT
    o.customer_id
    ,COUNT(DISTINCT o.order_id)                                                     orders_cnt
    ,SUM(op.item_quantity*COALESCE(p.product_price, 0)
        *(1-COALESCE(op.position_discount, 0)))                                     total_revenue
    ,MIN(o.order_date)                                                              first_order_date
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
WHERE o.delivery_state = 'California'
GROUP BY o.customer_id
HAVING EXTRACT(YEAR FROM MIN(o.order_date)) < 2022
), customer_segmented AS 
(
SELECT
    customer_id
    ,CONCAT(EXTRACT(YEAR FROM first_order_date), '-Q',
        QUARTER(first_order_date))                                                  acq_quarter
    ,CASE
        WHEN orders_cnt > 1 AND total_revenue >= 1000 THEN 'top_customer'
        WHEN orders_cnt = 1 AND total_revenue >= 1000 THEN 'risky_high_value'
        WHEN orders_cnt > 1                            THEN 'loyal_low_value'
        ELSE 'low_value'
    END                                                                             customer_segment
FROM customer_metrics
)
SELECT
    acq_quarter                                                                     acquisition_quarter
    ,COUNT(*)                                                                       total_acquired
    ,SUM(CASE WHEN customer_segment = 'top_customer'     THEN 1 ELSE 0 END)        top_customers
    ,SUM(CASE WHEN customer_segment = 'risky_high_value' THEN 1 ELSE 0 END)        risky_high_value
    ,SUM(CASE WHEN customer_segment = 'loyal_low_value'  THEN 1 ELSE 0 END)        loyal_low_value
    ,SUM(CASE WHEN customer_segment = 'low_value'        THEN 1 ELSE 0 END)        low_value
    ,ROUND(SUM(CASE WHEN customer_segment = 'top_customer'
        THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1)                                  top_pct
    ,ROUND(SUM(CASE WHEN customer_segment IN ('top_customer','loyal_low_value')
        THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1)                                  repeat_pct
FROM customer_segmented
GROUP BY acq_quarter
ORDER BY acq_quarter;
 
/*================================================================================================================================================================================================
Fragment wyniku zapytania:
 
| acquisition_quarter | total | top | risky | loyal | low | top%  | repeat% |
|---------------------|-------|-----|-------|-------|-----|-------|---------|
| 2018-Q1             |    12 |   4 |     0 |     4 |   4 |  33,3 |   66,7 |
| 2018-Q2             |    43 |  20 |     0 |    15 |   8 |  46,5 |   81,4 |
| 2018-Q3             |    38 |   9 |     2 |    18 |   9 |  23,7 |   71,1 |
| 2018-Q4             |    67 |  16 |     1 |    25 |  25 |  23,9 |   61,2 |
| 2019-Q1             |    32 |  14 |     2 |     9 |   7 |  43,8 |   71,9 |
| 2019-Q2             |    33 |   6 |     3 |    11 |  13 |  18,2 |   51,5 |
| 2019-Q3             |    28 |   5 |     1 |    10 |  12 |  17,9 |   53,6 |
| 2019-Q4             |    54 |  12 |     6 |    17 |  19 |  22,2 |   53,7 |
| 2020-Q1             |    31 |   6 |     1 |    10 |  14 |  19,4 |   51,6 |
| 2020-Q2             |    27 |   5 |     0 |     9 |  13 |  18,5 |   51,9 |
| 2020-Q3             |    36 |  10 |     4 |    10 |  12 |  27,8 |   55,6 |
| 2020-Q4             |    53 |   9 |     3 |    19 |  22 |  17,0 |   52,8 |
| 2021-Q1             |    22 |   0 |     3 |     7 |  12 |   0,0 |   31,8 |
| 2021-Q2             |    27 |   2 |     1 |     2 |  22 |   7,4 |   14,8 |
| 2021-Q3             |    29 |   2 |     6 |     4 |  17 |   6,9 |   20,7 |
| 2021-Q4             |    33 |   0 |     6 |     3 |  24 |   0,0 |    9,1 |
 
📝 Uwagi i refleksje
   Dane pokazują dramatyczną zmianę w składzie segmentów w czasie.
 
   Kohorty 2018: udział top_customer między 24–47%, wskaźniki powtarzalności 61–81%. Wczesna baza klientów
   była mocno przechylona w stronę klientów o wysokiej wartości i powtarzalnych zakupach.
 
   Kohorty 2019–2020: udział top_customer stabilizuje się na poziomie 17–28%, wskaźniki powtarzalności
   około 52–56%. Bardziej zrównoważony, ale wciąż zdrowy profil akwizycji.
 
   Kohorty 2021: udział top_customer spada do 0–7%, wskaźniki powtarzalności spadają do 9–32%.
   Dominującym segmentem staje się low_value (kupujący jednorazowo z przychodem < 1 000).
 
KLUCZOWE ZASTRZEŻENIE — tenure bias:
   Ten wzorzec jest wizualnie uderzający, ale w pewnym stopniu oczekiwany. Klienci pozyskani w 2018
   mieli ~4 lata na budowanie przychodu i wykazanie powtarzalności zakupów. Klienci pozyskani w Q4 2021
   mieli co najwyżej ~2 miesiące. Część tych klientów „low_value" ostatecznie przekroczy próg 1 000
   i dokona ponownych zakupów — po prostu nie mieli jeszcze na to czasu.
 
   Zapytanie 5️⃣.4️⃣ kontroluje ten błąd systematyczny, porównując kohorty w identycznych oknach 90-dniowych.
   Zmiana w składzie segmentów jest realna w danych, ale jej interpretacja wymaga ostrożności.
================================================================================================================================================================================================*/
 
/*================================================================================================================================================================================================
5️⃣.2️⃣ Struktura przychodów: nowi vs powracający klienci × jakość akwizycji
Cel: Rozłożenie kwartalnego przychodu na wkład od nowo pozyskanych klientów
         vs klientów powracających, z krzyżowym odniesieniem do jakości nowych akwizycji.
Kontekst: Oryginalna wersja tego zapytania porównywała łączny miesięczny przychód z segmentami
            nowych klientów — ale większość przychodu w danym okresie pochodzi od klientów pozyskanych WCZEŚNIEJ.
            To porównanie tworzyło fałszywą korelację. Ta wersja rozdziela dwa strumienie przychodowe,
            abyśmy mogli ocenić faktyczne zależności.
 
            „Nowe" zamówienie definiowane jest jako zamówienie złożone w tym samym miesiącu
            co pierwsze zamówienie klienta w Kalifornii.
================================================================================================================================================================================================*/

-- customer_first uwzględnia WSZYSTKICH klientów (również pozyskanych w 2022), ponieważ potrzebujemy ich
-- first_order_date do prawidłowej klasyfikacji zamówień jako „nowe" vs „powracające" w quarterly_revenue.
-- Jest to celowo szerszy zakres niż customer_metrics, który wyklucza 2022 na potrzeby segmentacji.
WITH customer_first AS
(
-- Data pierwszego zamówienia per klient (uwzględnia zamówienia z 2022 dla dokładnej atrybucji)
SELECT
    customer_id
    ,MIN(order_date)                                                                first_order_date
FROM orders
WHERE delivery_state = 'California'
GROUP BY customer_id
), customer_metrics AS
(
-- Pełna historia na potrzeby przypisania segmentów (akwizycje z 2022 wykluczone z segmentacji)
SELECT
    o.customer_id
    ,COUNT(DISTINCT o.order_id)                                                     orders_cnt
    ,SUM(op.item_quantity*COALESCE(p.product_price, 0)
        *(1-COALESCE(op.position_discount, 0)))                                     total_revenue
    ,MIN(o.order_date)                                                              first_order_date
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
WHERE o.delivery_state = 'California'
GROUP BY o.customer_id
HAVING EXTRACT(YEAR FROM MIN(o.order_date)) < 2022
), customer_segmented AS
(
SELECT
    customer_id
    ,first_order_date
    ,CONCAT(EXTRACT(YEAR FROM first_order_date), '-Q',
        QUARTER(first_order_date))                                                  acq_quarter
    ,CASE
        WHEN orders_cnt > 1 AND total_revenue >= 1000 THEN 'top_customer'
        WHEN orders_cnt = 1 AND total_revenue >= 1000 THEN 'risky_high_value'
        WHEN orders_cnt > 1                            THEN 'loyal_low_value'
        ELSE 'low_value'
    END                                                                             customer_segment
FROM customer_metrics
), segment_by_quarter AS
(
SELECT
    acq_quarter
    ,SUM(CASE WHEN customer_segment = 'top_customer'     THEN 1 ELSE 0 END)        top_customers
    ,SUM(CASE WHEN customer_segment = 'risky_high_value' THEN 1 ELSE 0 END)        risky_high_value
    ,SUM(CASE WHEN customer_segment = 'loyal_low_value'  THEN 1 ELSE 0 END)        loyal_low_value
    ,SUM(CASE WHEN customer_segment = 'low_value'        THEN 1 ELSE 0 END)        low_value
    ,COUNT(*)                                                                       total_new_customers
FROM customer_segmented
GROUP BY acq_quarter
), quarterly_revenue AS
(
-- Dekompozycja przychodów: zamówienia nowych klientów vs zamówienia klientów powracających
-- Rok 2022 wykluczony z wyników; „nowe" zamówienie to zamówienie złożone w miesiącu pierwszego zamówienia klienta
SELECT
    CONCAT(EXTRACT(YEAR FROM o.order_date), '-Q',
        QUARTER(o.order_date))                                                      quarter
    ,EXTRACT(YEAR FROM o.order_date)                                                yr
    ,QUARTER(o.order_date)                                                          q
    ,ROUND(SUM(op.item_quantity*COALESCE(p.product_price, 0)
        *(1-COALESCE(op.position_discount, 0))), 2)                                 total_rev
    ,ROUND(SUM(CASE
        WHEN DATE_FORMAT(o.order_date, '%Y-%m') = DATE_FORMAT(cf.first_order_date, '%Y-%m')
        THEN op.item_quantity*COALESCE(p.product_price, 0)
            *(1-COALESCE(op.position_discount, 0))
        ELSE 0
    END), 2)                                                                        new_cust_rev
    ,ROUND(SUM(CASE
        WHEN DATE_FORMAT(o.order_date, '%Y-%m') != DATE_FORMAT(cf.first_order_date, '%Y-%m')
        THEN op.item_quantity*COALESCE(p.product_price, 0)
            *(1-COALESCE(op.position_discount, 0))
        ELSE 0
    END), 2)                                                                        ret_cust_rev
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
JOIN customer_first cf ON o.customer_id = cf.customer_id
WHERE o.delivery_state = 'California'
  AND EXTRACT(YEAR FROM o.order_date) < 2022
GROUP BY quarter, yr, q
), revenue_yoy AS
(
SELECT
    quarter
    ,yr
    ,q
    ,total_rev                                                                      cyr_rev
    ,LAG(total_rev) OVER (
        PARTITION BY q
        ORDER BY yr)                                                                lyr_rev
    ,ROUND((total_rev - LAG(total_rev) OVER (
        PARTITION BY q
        ORDER BY yr)) /
        NULLIF(LAG(total_rev) OVER (
        PARTITION BY q
        ORDER BY yr), 0)*100.0, 2)                                                  rev_pct_diff
    ,new_cust_rev
    ,ret_cust_rev
    ,ROUND(new_cust_rev * 100.0 / NULLIF(total_rev, 0), 1)                         new_cust_rev_pct
FROM quarterly_revenue
)
SELECT
    r.quarter
    ,r.cyr_rev
    ,r.lyr_rev
    ,r.rev_pct_diff
    ,r.new_cust_rev
    ,r.ret_cust_rev
    ,r.new_cust_rev_pct
    ,COALESCE(s.top_customers, 0)                                                   top_customers
    ,COALESCE(s.risky_high_value, 0)                                                risky_high_value
    ,COALESCE(s.loyal_low_value, 0)                                                 loyal_low_value
    ,COALESCE(s.low_value, 0)                                                       low_value
    ,COALESCE(s.total_new_customers, 0)                                             total_new_customers
FROM revenue_yoy r
LEFT JOIN segment_by_quarter s ON r.quarter = s.acq_quarter
ORDER BY r.quarter;
 
/*================================================================================================================================================================================================
Fragment wyniku zapytania:
 
| quarter | cyr_rev   | lyr_rev   | rev_pct_diff | new_cust_rev | ret_cust_rev | new%  | top | risky | loyal | low | new_cust |
|---------|-----------|-----------|--------------|--------------|--------------|-------|-----|-------|-------|-----|----------|
| 2018-Q1 |  3 256,95 |      NULL |         NULL |     3 256,95 |         0,00 | 100,0 |   4 |     0 |     4 |   4 |       12 |
| 2018-Q2 | 20 083,21 |      NULL |         NULL |    20 083,21 |         0,00 | 100,0 |  20 |     0 |    15 |   8 |       43 |
| 2018-Q3 | 25 157,12 |      NULL |         NULL |    22 913,32 |     2 243,80 |  91,1 |   9 |     2 |    18 |   9 |       38 |
| 2018-Q4 | 22 805,19 |      NULL |         NULL |    19 741,56 |     3 063,63 |  86,6 |  16 |     1 |    25 |  25 |       67 |
| 2019-Q1 | 24 741,12 |  3 256,95 |       659,63 |    20 638,53 |     4 102,60 |  83,4 |  14 |     2 |     9 |   7 |       32 |
| 2019-Q2 | 22 395,39 | 20 083,21 |        11,51 |    18 002,50 |     4 392,89 |  80,4 |   6 |     3 |    11 |  13 |       33 |
| 2019-Q3 | 15 343,97 | 25 157,12 |       -39,01 |     9 979,32 |     5 364,65 |  65,0 |   5 |     1 |    10 |  12 |       28 |
| 2019-Q4 | 30 826,62 | 22 805,19 |        35,18 |    24 445,34 |     6 381,28 |  79,3 |  12 |     6 |    17 |  19 |       54 |
| 2020-Q1 | 17 415,10 | 24 741,12 |       -29,61 |    11 849,45 |     5 565,65 |  68,0 |   6 |     1 |    10 |  14 |       31 |
| 2020-Q2 | 27 129,42 | 22 395,39 |        21,14 |     7 271,37 |    19 858,05 |  26,8 |   5 |     0 |     9 |  13 |       27 |
| 2020-Q3 | 36 663,72 | 15 343,97 |       138,90 |    26 257,12 |    10 406,60 |  71,6 |  10 |     4 |    10 |  12 |       36 |
| 2020-Q4 | 40 716,83 | 30 826,62 |        32,08 |    23 077,68 |    17 639,15 |  56,7 |   9 |     3 |    19 |  22 |       53 |
| 2021-Q1 | 31 525,28 | 17 415,10 |        81,03 |     9 354,14 |    22 171,14 |  29,7 |   0 |     3 |     7 |  12 |       22 |
| 2021-Q2 | 26 714,29 | 27 129,42 |        -1,53 |     6 444,80 |    20 269,49 |  24,1 |   2 |     1 |     2 |  22 |       27 |
| 2021-Q3 | 42 513,58 | 36 663,72 |        15,95 |    19 441,16 |    23 072,42 |  45,7 |   2 |     6 |     4 |  17 |       29 |
| 2021-Q4 | 47 976,29 | 40 716,83 |        17,83 |    17 754,29 |    30 222,00 |  37,0 |   0 |     6 |     3 |  24 |       33 |
 
📝 Uwagi i refleksje
 
   Najważniejszym trendem jest wzrost przychodu od klientów powracających (ret_cust_rev):
   z 0 w Q1 2018 (naturalnie — biznes dopiero startował) do 30 222 w Q4 2021 — co stanowi
   63% łącznego kwartalnego przychodu. To oznaka dojrzewającego, zdrowego biznesu,
   który skutecznie utrzymuje i monetyzuje swoją istniejącą bazę klientów.
 
   Zmiana w strukturze akwizycji (mniej top_customers w 2021) jest widoczna, ale jej wpływ
   biznesowy jest mniejszy, niż się początkowo wydawał. W 2021:
   - Q1: 70,3% przychodu pochodziło od klientów powracających, mimo zerowej akwizycji top_customer
   - Q4: 63,0% przychodu od klientów powracających, przy łącznym wzroście przychodu +17,83% YoY
 
   To oznacza, że wzrost przychodów Kalifornii w 2021 roku był napędzany przychodem od klientów
   powracających — skumulowaną wartością klientów pozyskanych w latach wcześniejszych, którzy
   kontynuowali zakupy.
 
   Skład segmentów nowych akwizycji ma znaczenie dla przyszłej stabilności, ale bieżąca
   trajektoria przychodowa jest podtrzymywana przez silną bazę klientów powracających.
 
Etykiety segmentów dla akwizycji z 2021 podlegają tenure bias (patrz zapytanie 5️⃣.4️⃣).
   Wielu klientów zaklasyfikowanych dziś jako „low_value" może awansować do wyższych segmentów z upływem czasu.
================================================================================================================================================================================================*/
 
/*================================================================================================================================================================================================
5️⃣.3️⃣ Wskaźnik retencji 30 / 90 / 180 dni według segmentu klienta (z korektą right-censoring)
Cel: Zbadanie, czy top_customers utrzymują się lepiej niż klienci loyal_low_value.
Kontekst: Jeśli top_customers utrzymują się z wyższym wskaźnikiem, to waliduje segmentację opartą
            na przychodzie i potwierdza, że pozyskiwanie kupujących o wysokim przychodzie i powtarzalności
            jest warte inwestycji.
 
Uwagi metodologiczne:
 
    1. Retencja mierzona jest per zdarzenie zakupowe (każde zamówienie to wiersz), nie per unikalny klient.
       Klient z 10 zamówieniami wnosi 10 wierszy do mianownika. Mierzymy „jaka frakcja zdarzeń zakupowych
       jest kontynuowana kolejnym zakupem w ciągu X dni."
 
    2. Segmenty low_value i risky_high_value to kupujący jednorazowo (orders_cnt = 1).
       Z DEFINICJI nie mają kolejnego zamówienia, więc ich retencja gwarantowanie wynosi 0%.
       To konsekwencja logiki segmentacji, nie wynik analityczny.
       Sensowne porównanie dotyczy wyłącznie top_customer i loyal_low_value.
 
    3. Korekta right-censoring: zdarzenie zakupowe kwalifikuje się do danego okna retencji tylko wtedy,
       gdy pełne okno mieści się w dostępnych danych (kończących się 25.01.2022).
       Bez tego zamówienia z końca 2021 wyglądałyby na „nieutrzymane" po prostu dlatego, że nie było
       wystarczającego czasu obserwacji — co sztucznie zaniżałoby wskaźniki retencji.
       Przykład: zamówienie z grudnia 2021 ma jedynie ~25 dni danych follow-up, więc jest wykluczane
       z okien 90-dniowego i 180-dniowego, ale uwzględnione w oknie 30-dniowym.
 
    4. Klienci pozyskani w 2022 są wykluczeni z segmentacji, ale ich zamówienia ze stycznia 2022
       służą jako prawidłowe cele next_order dla zakupów z końca 2021.
================================================================================================================================================================================================*/
 
WITH customer_metrics AS
(
SELECT
    o.customer_id
    ,COUNT(DISTINCT o.order_id)                                                     orders_cnt
    ,SUM(op.item_quantity*COALESCE(p.product_price, 0)
        *(1-COALESCE(op.position_discount, 0)))                                     total_revenue
FROM orders o
JOIN order_positions op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
WHERE o.delivery_state = 'California'
GROUP BY o.customer_id
HAVING EXTRACT(YEAR FROM MIN(o.order_date)) < 2022
), customer_segmented AS
(
SELECT
    customer_id
    ,CASE
        WHEN orders_cnt > 1 AND total_revenue >= 1000 THEN 'top_customer'
        WHEN orders_cnt = 1 AND total_revenue >= 1000 THEN 'risky_high_value'
        WHEN orders_cnt > 1                            THEN 'loyal_low_value'
        ELSE 'low_value'
    END                                                                             customer_segment
FROM customer_metrics
), customer_orders AS
(
-- Wszystkie zamówienia z Kalifornii uwzględniając 2022 — potrzebne jako prawidłowe cele next_order.
-- Filtr right-censoring w końcowym SELECT kontroluje kwalifikowalność.
SELECT DISTINCT
    o.customer_id
    ,o.order_id
    ,o.order_date
FROM orders o
WHERE o.delivery_state = 'California'
  AND o.customer_id IN (SELECT customer_id FROM customer_segmented)
), customer_next_purchase AS
(
SELECT
    a.customer_id
    ,a.order_date                                                                   current_order_date
    ,s.customer_segment
    ,LEAD(a.order_date) OVER (
        PARTITION BY a.customer_id
        ORDER BY a.order_date, a.order_id)                                          next_order_date
FROM customer_orders a
JOIN customer_segmented s ON a.customer_id = s.customer_id
)
SELECT
    customer_segment
 
    -- Retencja 180-dniowa (tylko zdarzenia zakupowe z pełnym 180-dniowym oknem obserwacji)
    ,COUNT(CASE
        WHEN DATEDIFF('2022-01-25', current_order_date) >= 180
        THEN 1
    END)                                                                            eligible_180d
    ,COUNT(CASE
        WHEN DATEDIFF('2022-01-25', current_order_date) >= 180
         AND DATEDIFF(next_order_date, current_order_date) <= 180
        THEN 1
    END)                                                                            retained_180d
    ,ROUND(
        COUNT(CASE
            WHEN DATEDIFF('2022-01-25', current_order_date) >= 180
             AND DATEDIFF(next_order_date, current_order_date) <= 180
            THEN 1
        END) * 100.0 /
        NULLIF(COUNT(CASE
            WHEN DATEDIFF('2022-01-25', current_order_date) >= 180
            THEN 1
        END), 0)
    , 2)                                                                            retention_rate_180d_pct
 
    -- Retencja 90-dniowa (tylko zdarzenia zakupowe z pełnym 90-dniowym oknem obserwacji)
    ,COUNT(CASE
        WHEN DATEDIFF('2022-01-25', current_order_date) >= 90
        THEN 1
    END)                                                                            eligible_90d
    ,COUNT(CASE
        WHEN DATEDIFF('2022-01-25', current_order_date) >= 90
         AND DATEDIFF(next_order_date, current_order_date) <= 90
        THEN 1
    END)                                                                            retained_90d
    ,ROUND(
        COUNT(CASE
            WHEN DATEDIFF('2022-01-25', current_order_date) >= 90
             AND DATEDIFF(next_order_date, current_order_date) <= 90
            THEN 1
        END) * 100.0 /
        NULLIF(COUNT(CASE
            WHEN DATEDIFF('2022-01-25', current_order_date) >= 90
            THEN 1
        END), 0)
    , 2)                                                                            retention_rate_90d_pct
 
    -- Retencja 30-dniowa (tylko zdarzenia zakupowe z pełnym 30-dniowym oknem obserwacji)
    ,COUNT(CASE
        WHEN DATEDIFF('2022-01-25', current_order_date) >= 30
        THEN 1
    END)                                                                            eligible_30d
    ,COUNT(CASE
        WHEN DATEDIFF('2022-01-25', current_order_date) >= 30
         AND DATEDIFF(next_order_date, current_order_date) <= 30
        THEN 1
    END)                                                                            retained_30d
    ,ROUND(
        COUNT(CASE
            WHEN DATEDIFF('2022-01-25', current_order_date) >= 30
             AND DATEDIFF(next_order_date, current_order_date) <= 30
            THEN 1
        END) * 100.0 /
        NULLIF(COUNT(CASE
            WHEN DATEDIFF('2022-01-25', current_order_date) >= 30
            THEN 1
        END), 0)
    , 2)                                                                            retention_rate_30d_pct
 
FROM customer_next_purchase
GROUP BY customer_segment
ORDER BY retention_rate_90d_pct DESC;
 
/*================================================================================================================================================================================================
Fragment wyniku zapytania:
 
| customer_segment | eligible_180d | retained_180d | rate_180d | eligible_90d | retained_90d | rate_90d | eligible_30d | retained_30d | rate_30d |
|------------------|---------------|---------------|-----------|--------------|--------------|----------|--------------|--------------|----------|
| top_customer     |           264 |            56 |     21,21 |          294 |           31 |    10,54 |          313 |            7 |     2,24 |
| loyal_low_value  |           324 |            45 |     13,89 |          362 |           28 |     7,73 |          399 |           14 |     3,51 |
| risky_high_value |            29 |             0 |      0,00 |           34 |            0 |     0,00 |           39 |            0 |     0,00 |
| low_value        |           198 |             0 |      0,00 |          217 |            0 |     0,00 |          233 |            0 |     0,00 |
 
📝 Uwagi i refleksje
   Sensowne porównanie dotyczy top_customer i loyal_low_value — oba segmenty to kupujący wielokrotnie,
   więc ich retencja odzwierciedla rzeczywiste różnice behawioralne.
 
   W dłuższych horyzontach czasowych top_customer prowadzi wyraźnie:
   - 180 dni: top_customer 21,21% vs loyal_low_value 13,89% (1,5× wyżej)
   - 90 dni:  top_customer 10,54% vs loyal_low_value 7,73% (1,4× wyżej)
 
   Natomiast w oknie 30-dniowym wzorzec się odwraca:
   - 30 dni:  top_customer 2,24% vs loyal_low_value 3,51%
 
   To istotne odkrycie. Klienci loyal_low_value są BARDZIEJ skłonni do szybkiego ponownego zakupu
   (w ciągu 30 dni), ale mniej skłonni do powrotu w dłuższych okresach.
   Top_customers wracają rzadziej w krótkim terminie, ale utrzymują zaangażowanie przez miesiące.
 
   Ten wzorzec sugeruje różne kadencje zakupowe: loyal_low_value mogą reprezentować częstych kupujących
   o małych koszykach, podczas gdy top_customers dokonują większych, bardziej przemyślanych zakupów
   w szerszych odstępach. Oba zachowania mają wartość biznesową — ale top_customers wnoszą
   nieproporcjonalnie więcej przychodu per zdarzenie retencyjne dzięki wyższej wartości zamówień.
 
   Segmenty low_value i risky_high_value wykazują 0% retencji we wszystkich oknach. To konsekwencja
   definicyjna: oba segmenty mają orders_cnt = 1, więc LEAD() zawsze zwraca NULL. Potwierdza to,
   że ci klienci nie wrócili, ale było to wiadome już z przypisania segmentów.
================================================================================================================================================================================================*/
 
/*================================================================================================================================================================================================
5️⃣.4️⃣ Wskaźnik ponownych zakupów kohortowych — kontrola tenure bias (granularność kwartalna)
Cel: Zweryfikowanie, czy spadek jakości akwizycji widoczny w zapytaniach 5️⃣.1️⃣ i 5️⃣.2️⃣
         jest realny, czy jest artefaktem krótszego czasu obserwacji dla nowszych klientów.
Kontekst: Klient pozyskany w 2018 miał ~4 lata na akumulację przychodu i ponownych zakupów.
            Klient pozyskany w Q4 2021 miał ~2 miesiące. To zapytanie porównuje kohorty
            w stałym 90-dniowym oknie od pierwszego zakupu — dając każdej kohorcie równą szansę.
 
            Uwzględnione są wyłącznie kohorty, których pierwszy zakup nastąpił co najmniej 90 dni
            przed końcem zbioru danych (25.01.2022), aby uniknąć błędu right-censoring.
================================================================================================================================================================================================*/
 
WITH first_orders AS
(
SELECT
    customer_id
    ,MIN(order_date)                                                                first_order_date
    ,CONCAT(EXTRACT(YEAR FROM MIN(order_date)), '-Q',
        QUARTER(MIN(order_date)))                                                   acq_quarter
    ,EXTRACT(YEAR FROM MIN(order_date))                                             acq_year
FROM orders
WHERE delivery_state = 'California'
GROUP BY customer_id
-- 90-dniowe okno obserwacji musi mieścić się w dostępnych danych
HAVING DATEDIFF('2022-01-25', MIN(order_date)) >= 90
), repeat_within_90d AS
(
SELECT
    f.customer_id
    ,f.acq_quarter
    ,f.acq_year
    ,CASE WHEN EXISTS (
        SELECT 1 FROM orders o2
        WHERE o2.customer_id = f.customer_id
          AND o2.order_date > f.first_order_date
          AND DATEDIFF(o2.order_date, f.first_order_date) <= 90
          AND o2.delivery_state = 'California'
    ) THEN 1 ELSE 0 END                                                            repeated_90d
FROM first_orders f
)
SELECT
    acq_quarter                                                                     acquisition_quarter
    ,COUNT(*)                                                                       total_acquired
    ,SUM(repeated_90d)                                                              repeated_within_90d
    ,ROUND(SUM(repeated_90d) * 100.0 / COUNT(*), 2)                                repeat_rate_90d_pct
FROM repeat_within_90d
GROUP BY acq_quarter
ORDER BY acq_quarter;
 
/*================================================================================================================================================================================================
Fragment wyniku zapytania:
 
| acquisition_quarter | total_acquired | repeated_within_90d | repeat_rate_90d_pct |
|---------------------|----------------|---------------------|---------------------|
| 2018-Q1             |             12 |                   0 |                0,00 |
| 2018-Q2             |             43 |                   2 |                4,65 |
| 2018-Q3             |             38 |                   1 |                2,63 |
| 2018-Q4             |             67 |                   3 |                4,48 |
| 2019-Q1             |             32 |                   0 |                0,00 |
| 2019-Q2             |             33 |                   1 |                3,03 |
| 2019-Q3             |             28 |                   2 |                7,14 |
| 2019-Q4             |             54 |                   6 |               11,11 |
| 2020-Q1             |             31 |                   1 |                3,23 |
| 2020-Q2             |             27 |                   2 |                7,41 |
| 2020-Q3             |             36 |                   1 |                2,78 |
| 2020-Q4             |             53 |                   6 |               11,32 |
| 2021-Q1             |             22 |                   1 |                4,55 |
| 2021-Q2             |             27 |                   2 |                7,41 |
| 2021-Q3             |             29 |                   3 |               10,34 |
| 2021-Q4             |             10 |                   1 |               10,00 |
 
Podsumowanie roczne:
 
| acquisition_year | total_acquired | repeated_within_90d | repeat_rate_90d_pct |
|------------------|----------------|---------------------|---------------------|
|             2018 |            160 |                   6 |                3,75 |
|             2019 |            147 |                   9 |                6,12 |
|             2020 |            147 |                  10 |                6,80 |
|             2021 |             88 |                   7 |                7,95 |
 
📝 Uwagi i refleksje
   Wskaźnik ponownych zakupów kohortowych opowiada historię, która bezpośrednio zaprzecza wcześniejszej analizie segmentacyjnej.
 
   Gdy każda kohorta otrzymuje to samo 90-dniowe okno obserwacji, dane pokazują konsekwentnie
   ROSNĄCY trend: 3,75% (2018) → 6,12% (2019) → 6,80% (2020) → 7,95% (2021).
 
   Kohorta 2021 ma najwyższy wskaźnik ponownych zakupów — niemal dwukrotność poziomu bazowego z 2018.
   To oznacza, że mniejsza liczba „top_customers" w kohortach 2021 (zapytania 5️⃣.1️⃣ i 5️⃣.2️⃣) była głównie
   artefaktem tenure bias, nie rzeczywistym spadkiem jakości klientów. Klienci pozyskani w 2021 po prostu
   mieli mniej czasu na akumulację przychodu i ponownych zakupów potrzebnych do przekroczenia progu top_customer
   (historyczny przychód >= 1 000 ORAZ zamówienia > 1). Przy równych oknach obserwacji faktycznie wracają
   z wyższym wskaźnikiem niż wcześniejsze kohorty.
 
   Rozkład kwartalny dodaje niuansów: kohorty Q4 konsekwentnie wykazują najwyższe wskaźniki ponownych zakupów
   w ramach każdego roku (4,48%, 11,11%, 11,32%, 10,00%), co sugeruje wzorce sezonowe — klienci pozyskani
   w okresie świątecznym mogą wykazywać silniejsze początkowe zaangażowanie.
 
   Istotne ograniczenie: Q4 2021 ma jedynie 10 kwalifikujących się klientów (vs 67 w Q4 2018),
   co czyni jego wskaźnik 10,00% mniej statystycznie wiarygodnym. Agregaty roczne zapewniają
   bardziej stabilne oszacowania do analizy trendów.
 
   Wniosek:
   Kalifornia prowadzi w przychodach wśród wszystkich stanów. Jej baza klientów NIE pogarsza się.
   Przy kontroli czasu obserwacji najnowsze kohorty wykazują rosnące wczesne zachowania ponownych zakupów.
   Wcześniejsza segmentacja (zapytania 5️⃣.1️⃣ i 5️⃣.2️⃣) poprawnie zidentyfikowała zmianę w składzie segmentów,
   ale błędnie przypisała ją spadkowi jakości akwizycji — podczas gdy w rzeczywistości była spowodowana
   krótszymi oknami obserwacji.
 
   Dekompozycja przychodów (zapytanie 5️⃣.2️⃣) ujawniła, że do 2021 roku 63–70% kwartalnego przychodu
   pochodziło od klientów powracających — skumulowanej wartości wcześniejszych kohort kontynuujących zakupy.
   To oznaka dojrzewającego biznesu, nie słabnącego.
 
   Analiza retencji (zapytanie 5️⃣.3️⃣) potwierdziła, że wśród kupujących wielokrotnie klienci o wyższym przychodzie
   wracają z wskaźnikiem ~1,4–1,5× wyższym niż klienci o niższym przychodzie w oknach 90 i 180 dni — natomiast
   kupujący wielokrotnie o niższym przychodzie wykazują silniejszą 30-dniową częstotliwość ponownych zakupów,
   co sugeruje różne, ale komplementarne kadencje zakupowe.
 
   Prawdziwa historia przychodów Kalifornii to historia rosnącej bazy klientów z poprawiającym się wczesnym
   zaangażowaniem — których pełna wartość życiowa dopiero się zmaterializuje. Implikacja strategiczna:
   „inwestuj w programy retencyjne, które przekształcą rosnący 90-dniowy wskaźnik ponownych zakupów
   w trwałą długoterminową lojalność."
 
   Ta analiza wykazała, że pojedyncza metryka przychodowa nie mówi prawie nic — i że nawet wieloetapowa
   analiza segmentacyjna może prowadzić do błędnych wniosków, gdy tenure bias nie jest kontrolowany.
   Pełna historia wymagała zrozumienia czasu, jakości klientów, wzorców akwizycji, zachowań retencyjnych
   i błędu systematycznego w pomiarze — krok po kroku.
================================================================================================================================================================================================*/
