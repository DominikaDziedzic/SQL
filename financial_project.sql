use financial16_64
# 1
/*Query that will prepare a summary of granted loans in the following dimensions:
year, quarter, month,
year, quarter,
year,
total.
As a summary result, display the following information:
total amount of loans,
average amount of loan,
total number of granted loans.*/
select
    extract(year from fl.date) as YEAR_date,
    extract(quarter from fl.date) as QUARTER_date,
    extract(month from fl.date) as MONTH_date,
    sum(fl.amount),
    avg(fl.amount),
    count(fl.amount)
from financial16_64.loan fl
group by 1, 2, 3 with rollup
order by 1, 2, 3        -- in quarter 3 the total is 1085352, in 1993 the total is 2619276

# 2
/*On the database page we can find information that there are a total of 682 loans granted in the database,
of which 606 were repaid and 76 were not.

Let's assume that we do not have information about which status corresponds to a repaid loan and which not.

In such a situation, we need to deduce this information from the data.

To do this, write a query that will try to answer the question of which statuses mean repaid loans
and which mean unpaid loans.*/
select
    count(loan_id)
from financial16_64.loan
where status = 'A' or status = 'C'    -- loans repaid

# 3
/*Query that will rank accounts according to the following criteria:
number of loans granted (descending),
amount of loans granted (descending),
average loan amount.
We only take into account repaid loans*/
with cte as (
select
    account_id,
    count(amount) quantity,
    sum(amount) sum,
    avg(amount) avg
from financial16_64.loan
where status in ('A', 'C')
group by account_id
)
select
    *,
    row_number() over (order by sum desc) sum_descending,
    row_number() over (order by quantity desc) quantity_descending
from cte
#  4
/*Check the balance of loans repaid by client gender.
Additionally, check in the manner of your choice whether the query is correct.*/
select
    c.gender,
    sum(l.amount) amount
from financial16_64.loan l
inner join financial16_64.account a on l.account_id = a.account_id
inner join financial16_64.disp d on a.account_id = d.account_id
inner join financial16_64.client c on d.client_id = c.client_id
where l.status in ('A', 'C') and d.type = 'OWNER'
group by c.gender with rollup
-- chceking
select
    sum(amount)
from financial16_64.loan
where status in ('A', 'C')
# 5
/*When modifying the queries from the task regarding repaid loans, answer the following questions:
Who has more repaid loans – women or men?
What is the average age of the borrower depending on gender?

Hints:
Save the result of the previously written and then modified query, e.g. to a temporary table and conduct the analysis on it.
You can calculate the age as the difference 2021 - the borrower's year of birth.*/
drop table if exists t_age
create temporary table t_age as
    (select
      c.gender,
      2024 - date_format(birth_date, '%Y') as age,
      count(l.amount) as number_of_loans
    from financial16_64.loan l
    inner join financial16_64.account a on l.account_id = a.account_id
    inner join financial16_64.disp d on a.account_id = d.account_id
    inner join financial16_64.client c on d.client_id = c.client_id
    where l.status in ('A', 'C') and d.type = 'OWNER'
    group by c.gender, 2 )
-- number of loans by gender
select
    gender,
    sum(number_of_loans) as number_of_loans_by_age
from t_age
group by gender
-- average age
select
    t_age.gender,
    avg(age)
from t_age
group by gender
# 6
/*Perform analyses that will answer the questions:
in which region are the most customers,
in which region were the most loans repaid in terms of quantity,
in which region were the most loans repaid in terms of amount.

Select only account owners as customers.*/
select
    A3,
    count(distinct client_id) number_of_customers
from financial16_64.district
inner join financial16_64.client c on district.district_id = c.district_id
group by A3
order by number_of_customers desc
-- region were the most loans repaid in terms of quantity
select
    d2.A3,
    count(l.amount) number_paid
from financial16_64.loan l
inner join financial16_64.account a on l.account_id = a.account_id
inner join financial16_64.disp d on a.account_id = d.account_id
inner join financial16_64.client c on d.client_id = c.client_id
inner join financial16_64.district d2 on a.district_id = d2.district_id
where l.status in ('A', 'C') and d.type = 'OWNER'
group by A3
order by number_paid desc
-- region were the largest loans repaid in terms of amount
select
    d2.A3,
    sum(l.amount) amount_paid
from financial16_64.loan l
inner join financial16_64.account a on l.account_id = a.account_id
inner join financial16_64.disp d on a.account_id = d.account_id
inner join financial16_64.client c on d.client_id = c.client_id
inner join financial16_64.district d2 on a.district_id = d2.district_id
where l.status in ('A', 'C') and d.type = 'OWNER'
group by A3
order by amount_paid desc

# 7
/*Using the query you obtained in the previous task, 
modify it to determine the percentage share of each region in the total amount of loans granted.*/
WITH cte AS (
    SELECT d2.district_id,
           count(distinct c.client_id) as customer_amount,
           sum(l.amount)               as loans_given_amount,
           count(l.amount)             as loans_given_count
    FROM financial16_64.loan as l
        INNER JOIN financial16_64.account a using (account_id)
        INNER JOIN financial16_64.disp as d using (account_id)
        INNER JOIN financial16_64.client as c using (client_id)
        INNER JOIN financial16_64.district as d2 on c.district_id = d2.district_id
    WHERE True
      AND l.status IN ('A', 'C')
      AND d.type = 'OWNER'
    GROUP BY d2.district_id
)
SELECT
    *,
    loans_given_amount / SUM(loans_given_amount) OVER () AS share
FROM cte
ORDER BY share DESC;

# 8
/*Check if there are any clients in the database who meet the following conditions:
the account balance exceeds 1000,
they have more than five loans,
they are born after 1990.
We assume that the account balance is the loan amount - payment.*/
SELECT
    c.client_id,
    c.birth_date,
    loan_id,
    sum(amount - payments) as client_balance,
    count(loan_id) as loans_amount
FROM loan as l
INNER JOIN account a using (account_id)
INNER JOIN disp as d using (account_id)
INNER JOIN client as c using (client_id)
WHERE True
  AND l.status IN ('A', 'C')
  AND d.type = 'OWNER'
  AND EXTRACT(YEAR FROM c.birth_date) > 1990
GROUP BY c.client_id, 3
HAVING SUM(amount - payments) > 1000 AND COUNT(loan_id) > 5

# 9
/*From the previous task, you probably already know that there are no customers who meet the required criteria.

Analyze which condition caused the lack of results.*/
SELECT
    c.client_id,
    c.birth_date,
    loan_id,
    sum(amount - payments) as client_balance,
    count(loan_id) as loans_amount
FROM loan as l
INNER JOIN account a using (account_id)
INNER JOIN disp as d using (account_id)
INNER JOIN client as c using (client_id)
WHERE True
  AND l.status IN ('A', 'C')
  AND d.type = 'OWNER'
  AND EXTRACT(YEAR FROM c.birth_date) < 1990  -- there are no customers after 1990
GROUP BY c.client_id, 3
HAVING SUM(amount - payments) > 1000 -- AND COUNT(loan_id) > 5  customers have one loan per person





