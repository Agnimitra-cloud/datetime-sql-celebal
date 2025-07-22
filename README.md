
This stored procedure helps you find out how many hours someone worked between two dates — but with real-life rules applied.

It doesn’t just count all the hours blindly. It smartly skips:

* All Sundays
* The 3rd, 4th, and 5th Saturdays of each month (assuming only 1st and 2nd Saturdays are working)

It also takes care of:

* Daily working hours .
* Lunch break deduction .
* Partial working days if the start or end time falls in the middle of a day

So, instead of giving you raw time difference, it gives a realistic total of actual working hours — just like it would be calculated in a company.

It’s great for use cases like:

* Employee timesheet reports
* Payroll systems
* Project time tracking
* HR management tools


