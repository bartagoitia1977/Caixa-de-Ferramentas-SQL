select rnk_tb.Department, rnk_tb.Employee, rnk_tb.Salary from
(select d.name as "Department", e.name as "Employee", e.salary as "Salary",
dense_rank() over (partition by d.name order by e.salary desc) as rnk
from Employee e, Department d
where e.departmentId = d.id) rnk_tb
where rnk_tb.rnk <= 3;