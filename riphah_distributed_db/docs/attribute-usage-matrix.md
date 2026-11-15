# FACULTY attribute usage matrix

The matrix below follows the stated Q4 and Q5 projections. `FID` is required as the row identity and reconstruction key even though it is not shown in the user-facing result.

| Attribute | Q4 directory | Q5 payroll | Allocation |
|---|---:|---:|---|
| FID | Yes, row key | Yes, row key | Both fragments |
| Name | Yes | Yes | FACULTY_PUBLIC, then join by FID for Q5 |
| Dept | Yes | No | FACULTY_PUBLIC |
| Campus | No | No | FACULTY_PUBLIC, retained to reconstruct the global relation |
| Phone | No | No | FACULTY_PUBLIC, retained to reconstruct the global relation |
| Email | Yes | No | FACULTY_PUBLIC |
| Salary | No | Yes | FACULTY_PAYROLL |
| BankAccount | No | Yes | FACULTY_PAYROLL |

`FACULTY_PUBLIC(FID, Name, Dept, Campus, Phone, Email)` is replicated at Main, Lahore and Faisalabad. `FACULTY_PAYROLL(FID, Salary, BankAccount)` is stored only at Main. The two fragments overlap on `FID`, which is sufficient to reconstruct the original FACULTY relation with a join. Q5 obtains Name from the public fragment and the sensitive fields from the payroll fragment.

The split keeps salary and bank account values out of the two remote campus databases. A view can simplify the join, but a view alone does not physically separate the sensitive columns. Database privileges are still needed, and the view must not be granted to directory-only users.
