# 🛒 Portfolio Analityczne SQL — E-commerce
> MySQL 8+ • Funkcje okna • CTEs • Analiza kohortowa i Pareto
> ~5 000 zamówień, 2018–2022, syntetyczny zbiór danych e-commerce zmodyfikowany na potrzeby analityczne.
---
## 👀 Dla Rekruterów — Dlaczego Warto Zajrzeć
| Co | W skrócie |
|------|---------|
| **Dopasowanie do roli** | Junior+ / Mid Analityk Danych, Analityk BI, Analityk E-commerce |
| **Poziom SQL** | Zaawansowany: wielotabelowe JOINy, CTEs, Window Functions, analiza kohortowa |
| **Wpływ biznesowy** | Wzrost przychodów, optymalizacja retencji, segmentacja klientów |
| **Jakość kodu** | Udokumentowane założenia, powtarzalne pipeline'y, czytelne formatowanie |
 
## 🔧 Narzędzia i Umiejętności
![MySQL](https://img.shields.io/badge/MySQL-8.0+-4479A1?logo=mysql&logoColor=white)
![DBeaver](https://img.shields.io/badge/DBeaver-IDE-382923?logo=dbeaver&logoColor=white)
| Kategoria | Techniki |
|----------|------------|
| **Podstawy** | `JOIN`, `GROUP BY`, `CASE WHEN`, `COALESCE`, `NULLIF` |
| **Window Functions** | `LAG`, `LEAD`, `DENSE_RANK`, `NTILE`, `MIN() OVER` |
| **Zaawansowane** | Wielopoziomowe CTEs, porównania MoM, logika kohortowa |
| **Metryki biznesowe** | Przychód, AoV , Wskaźnik Retencji, LTV Klienta, Pareto |
 
## 🗄️ Schemat (Widok Uproszczony)
orders ─┬── order_positions ─── products ─── product_groups
              ├── order_ratings
              └── order_returns
<details>
<summary>📋 Kliknij, żeby zobaczyć pełną strukturę tabel</summary>
| Tabela | Kluczowe kolumny |
|-------|-------------|
| `orders` | order_id, customer_id, order_date, shipping_date, shipping_mode |
| `order_positions` | order_id, product_id, item_quantity, position_discount |
| `products` | product_id, product_name, product_price, group_id |
| `product_groups` | group_id, category, product_group |
| `order_ratings` | order_id, rating |
| `order_returns` | order_id, next_order_free |
</details>

## 🏆 Przykładowy Wynik (Gotowy do Interpretacji)
**Miesięczny rozkład przychodów: nowi vs powracający klienci**
*Daty w formacie MM-RR dla zwięzłości.*
| miesiąc | przychód_nowi_klienci | przychód_powracający_klienci | udział_nowi_% | udział_powracający_% |
|------------|----------------------|----------------------------|----------------|---------------------|
| 01-18' | 324,04               | [NULL]                     | 100            | [NULL]               |
| 02-18' | 14 470,88            | [NULL]                     | 100            | [NULL]               |
| 03-18' | 8 326,86             | 225,23                      | 97,37          | 2,63                 |
| 04-18' | 39 682,17            | 1 150,89                    | 97,18          | 2,82                 |
| 05-18' | 23 230,08            | 3 270,22                     | 87,66          | 12,34                |
| 06-18' | 23 276,30            | 6 036,73                     | 79,41          | 20,59                |
 
## 📝 Udokumentowane Założenia
```sql
-- Przychód = liczony na dzień zamówienia (order_date)
-- Rabaty: mnożnik 0–1, NULL → traktowane jako 0
-- shipping_date < order_date → rekordy wykluczone
-- Nowy klient = pierwsze zamówienie w danym miesiącu kalendarzowym
```
