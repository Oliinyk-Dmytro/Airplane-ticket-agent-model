That is the model of buying airplane tickets by customers. 

Action takes place at an airport.

There are cashiers who can serve customers. Time that it takes to serve a customer is uniformly distributed.
The arrival of customers is exponentially distributed. When a customer arrives he chooses the shortest queue. 
If all queues are full, new cashier will be opened. A customer will buy a ticket when there is at least one free seat for the desired direction, otherwise he won’t buy a ticket. 

The model has the next parameters:
<br/>***SIMULATION-DURATION*** - duration time of the simulation. If it’s set to 0 or less the simulation has no time limits.
<br/>***INIT-CASHIER-COUNT*** - initial number of cashiers.
<br/>***MAX-QUEUE-LENGTH*** - maximum length of a cashier’s queue.
<br/>***MIN-SERVICE-TIME***, ***MAX-SERVICE-TIME*** - parameters of a uniform distribution: minumum and maximum duration of serving a customer.
<br/>***AVG-TIME-BETWEEN-CUSTOMERS***, ***MAX-TIME-BETWEEN-CUSTOMERS*** - parameters of exponential distribution. ***AVG-TIME-BETWEEN-CUSTOMERS*** discribes the mean parameter of exponential distribution. 
If ***MAX-TIME-RESTRICTION?*** parameter is true, a number that will be received acording to exponential distribution will be equal or less than ***MAX-TIME-BETWEEN-CUSTOMERS***, otherwise there is no limits.
