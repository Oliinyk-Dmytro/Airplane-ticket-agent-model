extensions [queue array]

globals [
  estimated-rate
  simulation-duration-seconds
  is-simulation-infinite?

  direction-names
  cashiers-count
  customers-count

  next-customer-time

  customer-clear-cycle

  avg-time-buy-ticket
]

breed [customers customer]
breed [cashiers cashier]
breed [directions direction]

customers-own[
  travel-direction-id
  serving-cashier-id
  is-served?
]

cashiers-own[
  serving-ids ; the queue of customers "who" (ids)
  ;queue-length ; the lenght of the queue
  serve-time ; a customer will have been served at a timestamp
  is-observable?
  is-fast-checked?
]

directions-own[
  id
  name
  is-available?
  total-seat-count
  free-seat-count
]

;;;;;;;;SETUP functions BEGIN

to setup-globals
  set estimated-rate (1 / avg-time-between-customers)

  set simulation-duration-seconds simulation-duration * 60
  ifelse simulation-duration > 0
  [set is-simulation-infinite? false]
  [set is-simulation-infinite? true]

  set cashiers-count 0
  set customers-count 0
  set next-customer-time 0
  set customer-clear-cycle 0

  set direction-names [
    "London" "New-York" "Kyiv" "Prague" "Berlin"
    "Paris" "Rome" "Nurnberg" "Washington" "Los Angeles"
    "Tokyo" "Singapore" "San Francisco"
  ]

end

to setup-directions
  create-directions 5
  foreach sort-on [who] directions [ a-direction -> ask a-direction [init-direction] ]
end

to setup-customers
end

to setup-cashiers
  create-cashiers init-cashier-count
  foreach sort-on [who] cashiers [ a-cashier -> ask a-cashier [init-cashier] ]
end

to setup-pathces
   ask patches [set pcolor white]
end

to setup
  clear-all

  set-default-shape turtles "person"
  set-default-shape directions "nothing"

  if max-time-restriction? and avg-time-between-customers >= max-time-between-customers
  [ error (word "Max time value between customers arrival must be higher than average time. Max time: " max-time-between-customers "; Average time: " avg-time-between-customers)]

  setup-globals
  setup-pathces
  setup-directions
  setup-customers
  setup-cashiers

  reset-ticks
end

;;;;;;;;SETUP functions END







;;;;;;;;DIRECTIONS functions BEGIN

to init-direction
  set id who

  set name one-of direction-names
  set total-seat-count (50 + random 150)
  set free-seat-count total-seat-count
  set is-available? true

  set ycor 0 - id
  set xcor max-pxcor - 1
  set-direction-label
end

to set-direction-label
  set label-color black
  set label (word name ": " free-seat-count "/" total-seat-count " seats")
end

to update-direction-list
  let to-update-directions directions with [(not is-available?)]

  debug-show
  debug-print (word " [DEBUG] update-direction-list:")
  if to-update-directions != nobody
  [
    ask to-update-directions [
      debug-print (word "\t direction: " direction who)
      debug-print (word "\t\t id = " [id] of direction who)
      debug-print (word "\t\t name = " [name] of direction who)
      debug-print (word "\t\t total-seat-count = " [total-seat-count] of direction who)
      debug-print (word "\t\t free-seat-count = " [free-seat-count] of direction who)

      let customer-count count customers with [travel-direction-id = [who] of myself]
      debug-print (word "\t\t customer count with travel-direction-id == current direction = " customer-count)

      if customer-count = 0 [ init-direction ]
    ]

]


end

;;;;;;;;DIRECTIONS functions END







;;;;;;;;CASHIER functions BEGIN

to init-cashier
  place-cashier

  set color green

  set serving-ids queue:create 0 ; 0 - fifo
  let nothing queue:remove serving-ids 0
  set serve-time -1

  set cashiers-count cashiers-count + 1
  set is-observable? true
  set is-fast-checked? false

  if cashiers-count > 7 [
    set is-observable? false
    place-cashier-label
  ]
end

to place-cashier
  ifelse cashiers-count < 7
  [
    set ycor -6
    set xcor (2 + cashiers-count * 4)

    debug-show
    debug-print (word " [DEBUG] place-cashier:")
    debug-print (word "\t xcor " xcor " ycor " ycor "\n")

    ask patch-at -1  0 [set pcolor brown]
    ask patch-at  1  0 [set pcolor brown]
    ask patch-at -1 -1 [set pcolor brown]
    ask patch-at  0 -1 [set pcolor brown]
    ask patch-at  1 -1 [set pcolor brown]
  ]
  [
    set ycor -6
    set xcor (2 + 7 * 4)
  ]
end

to place-cashier-label
  if not is-observable?[
    ask patch-at 1 -1 [
      set plabel-color black
      set plabel (word "Cashiers:")
    ]
    ask patch-at 1 -2 [
      set plabel-color black
      set plabel (word (cashiers-count - 7))
    ]
    ask patch-at 1 -3 [
      set plabel-color black
      set plabel (word "Customers: " )
    ]
    ask patch-at 1 -4 [
      let observable-customers sum [queue:length serving-ids] of min-n-of 7 cashiers [who]
      debug-show
      debug-print (word " [DEBUG] place-cashier-label:")
      debug-print (word "\t observable-customers = " observable-customers "; customers-count = " customers-count "; sub obs - total = " (customers-count - observable-customers) "\n")
      set plabel-color black
      set plabel (word (customers-count - observable-customers))
    ]
  ]
end

to add-to-queue [a-customer]
  queue:insert serving-ids a-customer ticks

  debug-show
  debug-print (word " [DEBUG] add-to-queue [a-customer]:")
  debug-print (word "\t A customer with id = " [who] of a-customer)
  debug-print (word "\t was add to a queue of cashier with id = " who)
  debug-print (word "\t Current queue length = " queue:length serving-ids "\n")
end

to-report get-next-serve-time
  let rand-value ( min-service-time + random (max-service-time - min-service-time + 1) )
  debug-show
  debug-print (word "\t next service time = " (ticks + rand-value) )
  report ticks + rand-value
end

to serve-customer

  ifelse serve-time = ticks
  [
    debug-show
    debug-print (word " [DEBUG] serve-customer:")
    debug-print (word "\t serve-time = ticks")

    let served-customer queue:remove serving-ids ticks

    let customer-direction direction [travel-direction-id] of served-customer

    let available-ticket-count [free-seat-count] of customer-direction
    let is-received-ticket? false

    debug-print (word "\t customer: " served-customer)

    debug-print (word "\t direction: " customer-direction)
    debug-print (word "\t\t id = " [id] of customer-direction)
    debug-print (word "\t\t name = " [name] of customer-direction)
    debug-print (word "\t\t total-seat-count = " [total-seat-count] of customer-direction)
    debug-print (word "\t\t free-seat-count = " [free-seat-count] of customer-direction)

    ifelse available-ticket-count > 0
    [
      set is-received-ticket? true
      ask customer-direction [
        set free-seat-count free-seat-count - 1
        if free-seat-count <= 0
        [ set is-available? false ]
      ]
       debug-print (word "\t Approved" )
    ]
    [
      set is-received-ticket? false
      debug-print (word "\t Rejected" )
    ]

    ask served-customer [
      set is-served? true
      ifelse is-received-ticket?
      [
        set color green
        set heading 270
      ]
      [
        set color red
        set heading 90
      ]
      jump 1
    ]
    ask customers with [serving-cashier-id = [who] of myself] [fd 1]

    if queue:length serving-ids > 0 [set serve-time get-next-serve-time]
    debug-print (word "\t serve-time = " serve-time "; current time = " ticks "; time span = " (serve-time - ticks))
  ]
  [
    if not is-fast-checked?
    [
      let top-queue-customer min-one-of customers with [serving-cashier-id = [who] of myself] [who]

      if top-queue-customer != nobody
      [
        debug-show
        debug-print (word " [DEBUG] serve-customer:")
        debug-print (word "\t serve-time != ticks && not is-fast-checked?")
        debug-print (word "\t who = " who "; who of customer = " [who] of top-queue-customer)

        let customer-direction direction [travel-direction-id] of top-queue-customer
        let available-ticket-count [free-seat-count] of customer-direction

        debug-print (word "\t customer: " top-queue-customer)
        debug-print (word "\t direction: " customer-direction)
        debug-print (word "\t\t id = " [id] of customer-direction)
        debug-print (word "\t\t name = " [name] of customer-direction)
        debug-print (word "\t\t total-seat-count = " [total-seat-count] of customer-direction)
        debug-print (word "\t\t free-seat-count = " [free-seat-count] of customer-direction)

        ifelse available-ticket-count <= 0
        [
          let served-customer queue:remove serving-ids ticks
          ask top-queue-customer [
            set is-served? true
            set color red
            set heading 90
            jump 1
          ]
          ask customers with [serving-cashier-id = [who] of myself] [fd 1]
          set is-fast-checked? false
        ]
        [set is-fast-checked? true]
      ]
    ]
  ]

end


;;;;;;;;CASHIER functions END







;;;;;;;;CUSTOMER functions BEGIN

to update-customer-position
  set customers-count customers-count - 1
  die
end

to ask-open-cashier
  hatch-cashiers 1 [ init-cashier ]
end

to-report get-next-customer-time
  let rand-value (1 + round random-exponential avg-time-between-customers)
  ifelse max-time-restriction? [
    ifelse rand-value > max-time-between-customers
    [ report ticks + max-time-between-customers ]
    [ report ticks + rand-value ]
  ]
  [ report ticks + rand-value ]
end

to init-customer
  set ycor min-pycor + 1
  set xcor 1
  set color yellow
  set heading 0

  set is-served? false
  set travel-direction-id [id] of one-of directions with [is-available?]
  set serving-cashier-id -1

  debug-show
  debug-print (word " [DEBUG] init-customer:")
  debug-print (word " \t travell-direction-id = " travel-direction-id "\n")
end

to choose-queue
  debug-show
  debug-print (word " [DEBUG] choose-queue:")

  let shortest-length [queue:length serving-ids] of min-one-of cashiers [queue:length serving-ids]

  if shortest-length >= max-queue-length
  [
    debug-print (word " \t shortest-length >= max-queue-length ==> open new cashier")
    ask-open-cashier
  ]

  let customer-id who
  let cashier-id [who] of min-one-of cashiers [queue:length serving-ids] ; a shortest cashier queue id
  set shortest-length [queue:length serving-ids] of min-one-of cashiers [queue:length serving-ids]

  debug-show
  debug-print (word " \t shortest-cashier-queue-id = " cashier-id "; cashier = " cashier cashier-id )

  let cashier-x [xcor] of cashier cashier-id
  let cashier-y [ycor] of cashier cashier-id

  set xcor cashier-x
  set ycor (cashier-y + -3 + -1 * [queue:length serving-ids] of cashier cashier-id)
  set serving-cashier-id cashier-id

  ask cashier cashier-id [
    add-to-queue (customer customer-id)
    place-cashier-label
    if shortest-length = 0
    [ set serve-time get-next-serve-time ]
  ]
  debug-print (word "\n")
end
;;;;;;;;CUSTOMER functions END






to go

  if not is-simulation-infinite? and simulation-duration-seconds = ticks [stop]

  if next-customer-time = ticks
  [
    debug-show
    debug-print (word " [DEBUG] go:")
    debug-print (word "\t next-customer-time == ticks ==> Create a new customer")

    create-customers 1 [
      init-customer
      set customers-count customers-count + 1
      choose-queue
    ]
    set next-customer-time get-next-customer-time
    debug-print (word "\t next-customer-time = " next-customer-time "; current time = " ticks "; time span = " (next-customer-time - ticks) "\n")
  ]

  ask cashiers [ serve-customer ]

  ask directions [ set-direction-label ]
  update-direction-list

  if customer-clear-cycle = 10 [
    ask customers with [is-served? = true] [ update-customer-position ]
    set customer-clear-cycle  0
  ]
  set customer-clear-cycle customer-clear-cycle + 1

  tick
end






to debug-print [string-to-print]
  if debug-mode?
  [print string-to-print]
end

to debug-show
  if debug-mode?
  [show ""]
end
@#$#@#$#@
GRAPHICS-WINDOW
286
17
688
420
-1
-1
11.94
1
10
1
1
1
0
0
0
1
0
32
-32
0
1
1
1
ticks
60.0

SLIDER
14
146
262
179
avg-time-between-customers
avg-time-between-customers
1
1200
5.0
1
1
Second
HORIZONTAL

SLIDER
14
81
261
114
min-service-time
min-service-time
1
90
60.0
1
1
Second
HORIZONTAL

SLIDER
14
113
261
146
max-service-time
max-service-time
1
180
90.0
1
1
Second
HORIZONTAL

SLIDER
21
49
136
82
init-cashier-count
init-cashier-count
1
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
135
49
250
82
max-queue-length
max-queue-length
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
14
17
261
50
simulation-duration
simulation-duration
-1
1000
300.0
1
1
minutes
HORIZONTAL

BUTTON
136
246
248
279
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
25
246
137
279
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
730
10
1481
233
Avg time for buying a ticket
NIL
NIL
0.0
10.0
0.0
0.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [queue:mean-wt serving-ids] of cashiers"

PLOT
730
233
1481
456
Avg ticket office load
NIL
NIL
0.0
10.0
0.0
0.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot customers-count / cashiers-count"

PLOT
730
455
1481
678
Avg queue length
NIL
NIL
0.0
10.0
0.0
0.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [queue:mean-length serving-ids] of cashiers"

MONITOR
30
283
135
328
NIL
estimated-rate
5
1
11

MONITOR
30
327
135
372
NIL
cashiers-count
3
1
11

MONITOR
30
371
135
416
NIL
customers-count
4
1
11

SLIDER
14
178
262
211
max-time-between-customers
max-time-between-customers
2
2000
300.0
1
1
Second
HORIZONTAL

SWITCH
14
211
157
244
max-time-restriction?
max-time-restriction?
0
1
-1000

TEXTBOX
311
187
461
205
NIL
10
0.0
1

SWITCH
156
211
262
244
debug-mode?
debug-mode?
1
1
-1000

MONITOR
138
283
243
328
current avg time
mean [queue:mean-wt serving-ids] of cashiers
2
1
11

MONITOR
138
327
243
372
current load
customers-count / cashiers-count
2
1
11

MONITOR
138
371
243
416
Current avg length
mean [queue:length serving-ids] of cashiers
2
1
11

@#$#@#$#@
## WHAT IS IT?

That is the model of buying airplane tickets by customers.  


## HOW IT WORKS

Action takes place at an airport. 

There are cashiers who can serve customers. Time that it takes to serve a customer is uniformly distributed. 

The arrival of customers is exponentially distributed. When a customer arrives he chooses the shortest queue. If all queues are full, new cashier will be opened. A customer is served when there is at least one free seat for the desired direction, otherwise he won't buy a ticket.

## HOW TO USE IT

The model has the next parameters:

SIMULATION-DURATION - duration time od the simulation. If it's set to 0 or less the simulation has no time limits.

INIT-CASHIER-COUNT - initial number of cashiers.

MAX-QUEUE-LENGTH - maximum length of a cashier's queue.

MIN-SERVICE-TIME, MAX-SERVICE-TIME - parameters of a uniform distribution: minumum and maximum duration of serving a customer.

AVG-TIME-BETWEEN-CUSTOMERS, MAX-TIME-BETWEEN-CUSTOMERS - parameters of exponential distribution. AVG-TIME-BETWEEN-CUSTOMERS discribes the mean parameter of exponential distribution. If MAX-TIME-RESTRICTION? parameter is true a number that will be received acording to exponential distribution will be equal or less than  MAX-TIME-BETWEEN-CUSTOMERS, otherwise there is no limits.



## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

nothing
true
0

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="simulationDuration">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initCashierCount">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minServiceTime">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxQueueLenth">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxServiceTime">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avgTimeBetweenCustomers">
      <value value="496"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
