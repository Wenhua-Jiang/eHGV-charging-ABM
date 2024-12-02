extensions [csv]

;1. global variables
globals [
  data                  ; Placeholder for imported data
  mins-per-tick         ; Minutes per simulation tick
  charger-types         ; Types of chargers available
  soc-min               ; Minimum state of charge (SOC) for vehicles
  soc-max               ; Maximum state of charge (SOC) for vehicles
  time-to-break-min     ; Minimum time before mandatory break for drivers.
  time-to-break-max     ; Maximum time before mandatory break for drivers.

  queue                 ; Queue for vehicles waiting for charging
  queue-location        ; Location information for the queue
  queue-length-max      ; Maximum capacity limit for the queue.

  queue1                ; List for managing the auxiliary queue
  queue2


  arrival-count        ; Counter for arriving vehicles.
  log-file-name        ; Name of the log file to record simulation data

  list-capacity        ;List for storing capacity-related data

  total-time-in-queue                           ;Total time vehicles spend in the queue
  total-trucks-in-queue                         ;Total number of trucks in the queue

  total-time-charging-not-break                 ;Total time vehicles spend charging without breaks
  total-vehicles-charging-not-break              ;Total number of vehicles charging without breaks

  total-extra-time-on-chargers                   ;Total extra time vehicles spend on chargers
  total-vehicles-spend-extra-time-on-chargers    ;Total number of vehicles spending extra time on chargers

  current-time              ; Current simulation time
  max-run-time              ; Maximum duration for the simulation run.


  total-num-chargers        ;Total number of chargers available

  small-vehicles-count      ;Count of small vehicles in the simulation
  large-vehicles-count      ;Count of large vehicles in the simulation


  list-arrival-time       ; List of scheduled arrival times for vehicles
  new-list-arrival-time   ; Updated list of scheduled arrival times
  arrival-time            ; Scheduled arrival time for vehicles
  shuffled-vehicles       ; List of vehicles after shuffling for randomized order
  hours-data              ; Data related to hourly vehicle arrivals
  list-h                  ; List of hours in a day
  current-day             ; Current day in the simulation
]


;2.patch variables
patches-own [
  patch-type        ; type of patch (parking, road, fast charger, slow charger, etc)
  max-power         ; max charger power (in kw)
]

breed [trucks truck]


;3. trucks varialbes
trucks-own [
  case               ; Specific case assigned to the truck
  status             ; Current activity or state of the truck
  arrival-soc        ; State of charge (%) upon arrival at a location
  current-soc        ; Current state of charge (%)
  battery-capacity   ; Battery capacity in kwh
  time-to-break      ; Time remaining until mandatory break
  break-time          ; Duration of the current break
  charging-time       ; Total time spent charging
  time-entered-queue    ; Time when the truck entered the charging queue
  time-entered-service  ; Time when the truck started charging
  time-complete-service ; Time when the truck completed charging
  time-entered-parking  ; Time when the truck entered a parking spot
  time-in-queue         ; Total time spent in the queue
  time-to-leave         ; Scheduled time to leave the charging station or parking spot
  time-charging-not-on-break  ; Time spent charging when not on a mandatory break
  extra-time-on-chargers      ; Additional time spent on chargers beyond the expected period
  t-manoeuvring               ; Time spent maneuvering into/out of charging/parking spots
  time-of-arrival             ; Exact time of arrival at a location
  arrival-day                 ; Day of arrival within the simulation period
  start-charging-day          ; Day when the truck starts charging within the simulation period
  charging-time-p1            ; Charging time for the first phase
  charging-time-p2            ; Charging time for the second phase

]


;4. Setup procedures
to setup

  clear-all                   ; Clears all previous simulation data
  reset-ticks                 ; Resets the simulation clock
  setup-globals               ; Initializes global variables
  setup-environment           ; Sets up the environment including roads and charging stations
  setup-trucks                ; Initializes truck agents in the simulation

  if (logging?) [ set-log-file-name ] ; If logging is enabled, set up the log file
end


; 5. Main Simulation Loop
to go

  ifelse (ticks < max-run-time)[

  create-vehicles-each-hour    ; Create vehicles based on the current hour

  ask turtles [                 ; Ask each truck to perform its step and check the queue in real time
  step-truck
  check-queue1-real-time
  ]

  ]
  [
    stop                       ; Stop the simulation when the maximum run time is reached
  ]

 if (logging?) [               ; Log the variables if logging is enabled
    log-variables
  ]

  tick                         ; Advance the simulation clock by one tick

end


; 6. Seed setup
to setup-seed
   ifelse (random-number-seed > 0) [
    random-seed random-number-seed
    ;print (word "Setting random seed: " random-number-seed)
  ] [ ; If the user-entered seed is 0 or less then just choose a new random one
    random-seed new-seed
  ]
end


; 7. global Setup
to setup-globals
  set queue []
  set queue1 []
  set queue2 []
  set list-capacity []

  set queue-location patch -1 1
  set queue-length-max 100
  set mins-per-tick 1
  set arrival-time current-time
  set soc-min 0
  set soc-max 100
  set time-to-break-min 10
  set time-to-break-max 30

  set total-time-in-queue 0
  set total-trucks-in-queue 0
  set total-time-charging-not-break 0
  set total-vehicles-charging-not-break 0

  set total-extra-time-on-chargers 0
  set total-vehicles-spend-extra-time-on-chargers 0

  set max-run-time 24 * 60 * num-days
  set total-num-chargers  num-ultra-fast-chargers + num-fast-chargers + num-slow-chargers
  set small-vehicles-count 0
  set large-vehicles-count 0

  set list-arrival-time []
  set new-list-arrival-time []
  set list-h [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23]
  set shuffled-vehicles []
  set hours-data []
  set current-day 0

end

; 8. Environment setup
to setup-environment

  ; Make the road before the chargers
  ask patches with [ pycor = 0 and pxcor <= 0 ] [
    set pcolor gray
    set patch-type "road"
  ]

    ask patches with [ pycor = 0 and pxcor >= 0 ] [
    set pcolor gray
    set patch-type "road"
  ]

    ask patches with [ pycor = 1 and pxcor <= 0 ] [
    set pcolor 99
    set patch-type "queue locations"
  ]

  ; Make parking spots for drivers' break
    ask patches with [ pycor = 2 and pxcor > -5 and pxcor <= (num-parking-spots - 5)  ] [
    set pcolor green
    set patch-type "parking spots"
  ]

  ; Specify different types of chargers
  set charger-types (list "ultra-fast charger" "fast charger" "slow charger")

  ; Make slow chargers
  ask patches with [ pycor = -2 and pxcor > 0 and pxcor <= num-ultra-fast-chargers] [
    set pcolor 34
    set patch-type "ultra-fast charger"
    set max-power 1000
  ]

  ; Make fast chargers
  ask patches with [ pycor = -1 and pxcor > 0 and pxcor <= num-fast-chargers ] [
    set pcolor 26
    set patch-type "fast charger"
    set max-power 350
  ]
  ; Make slow chargers
  ask patches with [ pycor = 1 and pxcor > 0 and pxcor <= num-slow-chargers ] [
    set pcolor 29
    set patch-type "slow charger"
    set max-power 150
  ]

end


; 9. Truck setup
to setup-trucks

  file-open arrivals-file ;; Replace with the actual filename
  while [not file-at-end?] [
    let line file-read-line  ;;; Read a line from the file
    set data csv:from-row line

    ;; Extract data items and create a list of lists (hours-data)
    let hour-item (list (item 0 data) (item 1 data) (item 2 data) (item 3 data) (item 4 data) (item 5 data) (item 6 data) (item 7 data) (item 8 data)(item 9 data))
    set hours-data lput hour-item hours-data

  ]

  file-close


end


; 10. vehicle creation
to create-vehicles-each-hour

  ; current day and time calculation
  set current-day int (ticks / 1440)

  ifelse current-day = 0 [
  set current-time ticks   ;; If it's the first day, set current-time directly from ticks
  ]
  [
    set current-time  (ticks - 1440 * current-day) ;; Calculate current-time in minutes based on the current day
  ]



 ; iterating through hourly list
  let idx 0

  while [idx < length list-h][

  let h item idx list-h

  if current-time >= h * 60 and current-time < (h + 1) * 60 [


  let hour-item item h hours-data  ;; Retrieve the hour-item list from hours-data

   let hour item 0 hour-item    ;; Extract the hour from hour-item
   let num1 item 1 hour-item    ;; Extract number of trucks for case 1 from hour-item
   let num2 item 2 hour-item    ;; Extract number of trucks for case 2 from hour-item
   let num3 item 3 hour-item
   let num4 item 4 hour-item
   let num5 item 5 hour-item
   let num6 item 6 hour-item
   let num7 item 7 hour-item
   let num8 item 8 hour-item
   let num9 item 9 hour-item



     if current-time = hour * 60 [

  ; Create vehicles based on the specified numbers
  repeat num1 [
  create-vehicle1
]

  repeat num2 [
  create-vehicle2
]

  repeat num3 [
  create-vehicle3
]

   repeat num4 [
  create-vehicle4
]

  repeat num5 [
  create-vehicle5
]

  repeat num6 [
  create-vehicle6
]

  repeat num7 [
  create-vehicle7
]

  repeat num8 [
  create-vehicle8
]

  repeat num9 [
  create-vehicle9
]

   let vehicle-items (list num1 num2 num3 num4 num5 num6 num7 num8 num9 ) ;; Create a list of vehicle counts

    let sum-total-trucks sum vehicle-items

    let all-vehicles (turtle-set (turtles with [breed = trucks]) (turtles with [breed = trucks]))  ;; Combine all truck turtles
    let vehicles-list sort all-vehicles   ;; Sort the combined list of truck turtles

    let current-vehicles-list sublist vehicles-list (length vehicles-list - sum-total-trucks) length vehicles-list ;; Get the current list of vehicles to schedule

    set shuffled-vehicles nobody
    ;
    set shuffled-vehicles shuffle current-vehicles-list  ;; Shuffle the current list of vehicles for random arrival order



   let ticks_per_hour 60 ;; Number of ticks per hour
   let ticks-per-truck floor (ticks_per_hour / sum-total-trucks) ;; Spread the vehicle arrivals evenly across the hour


    set arrival-time 0
    set list-arrival-time []
    repeat sum-total-trucks [
                 set arrival-time arrival-time + ticks-per-truck
                 set list-arrival-time lput arrival-time list-arrival-time

   ]

    let value-to-add ticks_per_hour * hour   ;; Calculate the value to add for each new arrival time
    set new-list-arrival-time []

    foreach list-arrival-time [
      t ->
      let new-arrival (t + value-to-add)
      set new-list-arrival-time lput new-arrival new-list-arrival-time
    ]


   assign-arrival-day     ;; Function to assign arrival day
   schedule-arrival-each-hour  ;; Function to schedule arrivals for each hour


]


]

  set idx idx + 1

  ]

end


; Sets the name of a log file (on setup). Only called if logging is on
to set-log-file-name
  ; Set a file name using a random number
  let random-number random 1000000 ; generates a random number
  set log-file-name (word "output/log-" random-number ".csv")

  ; Override old log files.
  if (file-exists? log-file-name) [ file-delete log-file-name ]

  ; Write the header
  file-open log-file-name
  ;file-write "Time,Turtle ID,case,status,arrival-soc,current-soc,battery-capacity,time-to-break,break-time,charging-time,time-entered-queue,time-entered-service, time-complete-service, time-entered-parking, time-in-queue, time-to-leave, time-charging-not-on-break, extra-time-on-chargers, t-manoeuvring, time-of-arrival, arrival-day, start-charging-day, x-coordinate, y-coordinate\n"
  file-print "Time,TurtleID,case,status,arrival_soc,current_soc,battery_capacity,time_to_break,break_time,charging_time,time_entered_queue,time_entered_service,time_complete_service,time_entered_parking,time_in_queue,time_to_leave,time_charging_not_on_break,extra_time_on_chargers,t_manoeuvring,time_of_arrival,arrival_day,start_charging_day,x_coordinate,y_coordinate"

end

; Logs a load of turtle variables at every iteration. Only called if logging is on/
to log-variables

  ; Open the file for appending, creating it if it does not exist
  file-open log-file-name

  ; Check if the file is empty and add headers if necessary
  ;if file-length file-name = 0 [
  ;  file-print "time,turtle-id,x-coordinate,y-coordinate"
  ;]

  ; Log data for each turtle
  ask turtles [
    ;file-type (word ticks ", " who ", " xcor ", " ycor "\n")
    file-print (word ticks ", " who ", " case ", " status ", " arrival-soc ", " current-soc ", " battery-capacity ", " time-to-break ", " break-time ", " charging-time ", " time-entered-queue ", " time-entered-service ", " time-complete-service ", " time-entered-parking ", " time-in-queue ", " time-to-leave ", " time-charging-not-on-break ", " extra-time-on-chargers ", " t-manoeuvring ", " time-of-arrival ", " arrival-day ", " start-charging-day ", " xcor ", " ycor)
  ]

  ; Close the file to ensure data is written
  file-close
end




; 11. assign-arrival-day procedure
to assign-arrival-day

    foreach shuffled-vehicles [v ->
      ask v [
      set arrival-day current-day  ;;Sets the arrival-day attribute of each truck to the current-day.
     ]
     ]
end


; 12. schedule-arrival-each-hour procedure
to schedule-arrival-each-hour

  let idx 0
  if idx < length shuffled-vehicles [
  foreach shuffled-vehicles [ t ->                 ;; Iterate over each vehicle (t) in shuffled-vehicles list
    let arrival-t item idx new-list-arrival-time   ;; Get the arrival time for the current vehicle (t) from new-list-arrival-time

    ask t [

           ifelse arrival-t < 1440 [            ;; Check if arrival-t is less than 1440 (minutes in a day)
          set time-of-arrival arrival-t         ;; Set the time-of-arrival attribute to arrival-t
        ]
        [
         set time-of-arrival arrival-t - 1440    ;; Adjust time-of-arrival if arrival-t is greater than or equal to 1440
        ]
      ]

    set idx idx + 1  ;; Increment idx for the next iteration
  ]
  ]


end




; create trucks for case 1
to create-vehicle1
  create-trucks 1 [
  ; Create vehicles of type 1 at specified hour
    set case "1"               ;; Set case attribute to "1"
    set status "driving"        ;; Set status attribute to "driving"
    set arrival-soc random soc-threshold-low + 1     ;; Generate random initial state of charge (SoC)
    set current-soc arrival-soc

    ifelse random-float 1 < ratio-large-vehicle [    ;; Set battery capacity based on probability ratio
  set battery-capacity 550
] [
  set battery-capacity 250
]

    set heading 90
    set xcor min-pxcor
    set ycor 0
    set shape "truck"


    set time-to-break random 11 ; Set time-to-break randomly
    set break-time 0
    set charging-time 0
    set color scale-color white arrival-soc soc-min soc-max  ;; Set color of the vehicle based on its arrival SoC
    set time-entered-queue 0
    set time-entered-service 0
    set time-in-queue 0
    set time-to-leave 0
    set extra-time-on-chargers 0
    set time-of-arrival 0
    set t-manoeuvring random 5 + time-manoeuvring     ;; Set manoeuvring time randomly
    set arrival-day 0                                 ;; Initialize arrival-day attribute to 0
    set start-charging-day current-day

    set charging-time-p1 0
    set charging-time-p2 0

    if battery-capacity = 250 [
      set small-vehicles-count small-vehicles-count + 1
    ]
    if battery-capacity = 550 [
      set large-vehicles-count large-vehicles-count + 1
    ]

  set list-capacity lput battery-capacity list-capacity


  ]

end


; create trucks for case 2
to create-vehicle2
  create-trucks 1 [
    set case "2"
    set status "driving"
     set arrival-soc random soc-threshold-low + 1
    set current-soc arrival-soc

    ifelse random-float 1 < ratio-large-vehicle [
  set battery-capacity 550
] [
  set battery-capacity 250
]


    set heading 90
    set xcor min-pxcor
    set ycor 0
    set shape "truck"


     set time-to-break random 20 + 11 ;case 5,8
    set break-time 0
    set charging-time 0
    set color scale-color white arrival-soc soc-min soc-max
    set time-entered-queue 0
    set time-entered-service 0
    set time-in-queue 0
    set time-to-leave 0
    set extra-time-on-chargers 0

    set time-of-arrival 0
    set t-manoeuvring random 5 + time-manoeuvring
    set arrival-day 0
    set start-charging-day current-day
    set charging-time-p1 0
    set charging-time-p2 0

    if battery-capacity = 250 [
      set small-vehicles-count small-vehicles-count + 1
    ]
    if battery-capacity = 550 [
      set large-vehicles-count large-vehicles-count + 1
    ]

  set list-capacity lput battery-capacity list-capacity

  ]

end

; create trucks for case 3
to create-vehicle3
  create-trucks 1 [

    set case "3"
    set status "driving"
     set arrival-soc random soc-threshold-low + 1
    set current-soc arrival-soc

    ifelse random-float 1 < ratio-large-vehicle [
  set battery-capacity 550
] [
  set battery-capacity 250
]

    set heading 90
    set xcor min-pxcor
    set ycor 0
    set shape "truck"


    set time-to-break random 210 + 31 ;case 6
    set break-time 0
    set charging-time 0
    set color scale-color white arrival-soc soc-min soc-max
    set time-entered-queue 0
    set time-entered-service 0
    set time-in-queue 0
    set time-to-leave 0
    set extra-time-on-chargers 0
;    set dwell-time 0
;    set num-vehicle-before 0
    set time-of-arrival 0
    set t-manoeuvring random 5 + time-manoeuvring
     set arrival-day 0
    set start-charging-day current-day
    set charging-time-p1 0
    set charging-time-p2 0


    if battery-capacity = 250 [
      set small-vehicles-count small-vehicles-count + 1
    ]
    if battery-capacity = 550 [
      set large-vehicles-count large-vehicles-count + 1
    ]

  set list-capacity lput battery-capacity list-capacity

  ]

end


; create trucks for case 4
to create-vehicle4
  create-trucks 1 [

    set case "4"
    set status "driving"

    let range-start (soc-threshold-high - soc-threshold-low - 1)
    let range-end soc-threshold-low + 1

    set arrival-soc random range-start + range-end

    set current-soc arrival-soc

    ifelse random-float 1 < ratio-large-vehicle [
  set battery-capacity 550
] [
  set battery-capacity 250
]

    set heading 90
    set xcor min-pxcor
    set ycor 0
    set shape "truck"


    set time-to-break random 11 ;case 4
    set break-time 0
    set charging-time 0
    set color scale-color white arrival-soc soc-min soc-max
    set time-entered-queue 0
    set time-entered-service 0
    set time-in-queue 0
    set time-to-leave 0
    set extra-time-on-chargers 0

    set time-of-arrival 0
    set t-manoeuvring random 5 + time-manoeuvring
     set arrival-day 0
    set start-charging-day current-day
    set charging-time-p1 0
    set charging-time-p2 0


    if battery-capacity = 250 [
      set small-vehicles-count small-vehicles-count + 1
    ]
    if battery-capacity = 550 [
      set large-vehicles-count large-vehicles-count + 1
    ]

  set list-capacity lput battery-capacity list-capacity

  ]

end

; create trucks for case 7
to create-vehicle7
  create-trucks 1 [
    set case "7"
    set status "driving"
    let range-start 10
    let range-end soc-threshold-high + 1

    set arrival-soc random range-start + range-end

    set current-soc arrival-soc

    ifelse random-float 1 < ratio-large-vehicle [
  set battery-capacity 550
] [
  set battery-capacity 250
]
    ;set battery-capacity one-of [250 550] ; assume 500 kwh battery

    set heading 90
    set xcor min-pxcor
    set ycor 0
    set shape "truck"


    set time-to-break random 11 ;case 7
    set break-time 0
    set charging-time 0
    set color scale-color white arrival-soc soc-min soc-max
    set time-entered-queue 0
    set time-entered-service 0
    set time-in-queue 0
    set time-to-leave 0
    set extra-time-on-chargers 0
;    set dwell-time 0
;    set num-vehicle-before 0
    set time-of-arrival 0
    set t-manoeuvring random 5 + time-manoeuvring
     set arrival-day 0
    set start-charging-day current-day
    set charging-time-p1 0
    set charging-time-p2 0


    if battery-capacity = 250 [
      set small-vehicles-count small-vehicles-count + 1
    ]
    if battery-capacity = 550 [
      set large-vehicles-count large-vehicles-count + 1
    ]

  set list-capacity lput battery-capacity list-capacity

  ]

end


; create trucks for case 5
to create-vehicle5
  create-trucks 1 [
    set case "5"
    set status "driving"
    let range-start (soc-threshold-high - soc-threshold-low - 1)
    let range-end soc-threshold-low + 1

    set arrival-soc random range-start + range-end
    set current-soc arrival-soc

    ifelse random-float 1 < ratio-large-vehicle [
  set battery-capacity 550
] [
  set battery-capacity 250
]

    set heading 90
    set xcor min-pxcor
    set ycor 0
    set shape "truck"


    set time-to-break random 20 + 11 ;medium
    set break-time 0
    set charging-time 0
    set color scale-color white arrival-soc soc-min soc-max
    set time-entered-queue 0
    set time-entered-service 0
    set time-in-queue 0
    set time-to-leave 0
    set extra-time-on-chargers 0
;    set dwell-time 0
;    set num-vehicle-before 0
    set time-of-arrival 0
    set t-manoeuvring random 5 + time-manoeuvring
    set arrival-day 0
    set start-charging-day current-day
    set charging-time-p1 0
    set charging-time-p2 0


    if battery-capacity = 250 [
      set small-vehicles-count small-vehicles-count + 1
    ]
    if battery-capacity = 550 [
      set large-vehicles-count large-vehicles-count + 1
    ]

  set list-capacity lput battery-capacity list-capacity

  ]

end


; create trucks for case 8
to create-vehicle8
  create-trucks 1 [
    set case "8"
    set status "driving"
    let range-start 10
    let range-end soc-threshold-high + 1

    set arrival-soc random range-start + range-end

    set current-soc arrival-soc

    ifelse random-float 1 < ratio-large-vehicle [
  set battery-capacity 550
] [
  set battery-capacity 250
]

    set heading 90
    set xcor min-pxcor
    set ycor 0
    set shape "truck"


    set time-to-break random 20 + 11 ;case 5,8
    set break-time 0
    set charging-time 0
    set color scale-color white arrival-soc soc-min soc-max
    set time-entered-queue 0
    set time-entered-service 0
    set time-in-queue 0
    set time-to-leave 0
    set extra-time-on-chargers 0
    set time-of-arrival 0
    set t-manoeuvring random 5 + time-manoeuvring
     set arrival-day 0
    set start-charging-day current-day
     set charging-time-p1 0
    set charging-time-p2 0


    if battery-capacity = 250 [
      set small-vehicles-count small-vehicles-count + 1
    ]
    if battery-capacity = 550 [
      set large-vehicles-count large-vehicles-count + 1
    ]

  set list-capacity lput battery-capacity list-capacity

  ]

end


; create trucks for case 6
to create-vehicle6
  create-trucks 1 [
    set case "6"
    set status "driving"
    ;set arrival-soc random 59 + 21 ;case 6
    let range-start (soc-threshold-high - soc-threshold-low - 1)
    let range-end soc-threshold-low + 1

    set arrival-soc random range-start + range-end
    set current-soc arrival-soc

    ifelse random-float 1 < ratio-large-vehicle [
  set battery-capacity 550
] [
  set battery-capacity 250
]

    set heading 90
    set xcor min-pxcor
    set ycor 0
    set shape "truck"


    set time-to-break random 210 + 31 ;case 6
    set break-time 0
    set charging-time 0
    set color scale-color white arrival-soc soc-min soc-max
    set time-entered-queue 0
    set time-entered-service 0
    set time-in-queue 0
    set time-to-leave 0
    set extra-time-on-chargers 0
    set time-of-arrival 0
    set t-manoeuvring random 5 + time-manoeuvring
     set arrival-day 0
    set start-charging-day current-day
    set charging-time-p1 0
    set charging-time-p2 0


    if battery-capacity = 250 [
      set small-vehicles-count small-vehicles-count + 1
    ]
    if battery-capacity = 550 [
      set large-vehicles-count large-vehicles-count + 1
    ]

  set list-capacity lput battery-capacity list-capacity

  ]

end


; create trucks for case 9
to create-vehicle9
  create-trucks 1 [

    set case "9"
    set status "driving"
    let range-start 10
    let range-end soc-threshold-high + 1

    set arrival-soc random range-start + range-end

    set current-soc arrival-soc

    ifelse random-float 1 < ratio-large-vehicle [
  set battery-capacity 550
] [
  set battery-capacity 250
]

    set heading 90
    set xcor min-pxcor
    set ycor 0
    set shape "truck"


    set time-to-break random 210 + 31 ;case 9
    set break-time 0
    set charging-time 0
    set color scale-color white arrival-soc soc-min soc-max
    set time-entered-queue 0
    set time-entered-service 0
    set time-in-queue 0
    set time-to-leave 0
    set extra-time-on-chargers 0
;    set dwell-time 0
;    set num-vehicle-before 0
    set time-of-arrival 0
    set t-manoeuvring random 5 + time-manoeuvring
    set arrival-day 0
    set start-charging-day current-day
    set charging-time-p1 0
    set charging-time-p2 0


    if battery-capacity = 250 [
      set small-vehicles-count small-vehicles-count + 1
    ]
    if battery-capacity = 550 [
      set large-vehicles-count large-vehicles-count + 1
    ]

  set list-capacity lput battery-capacity list-capacity

  ]

end




; 13 beginning service procedure
to begin-service

       ; find available charger
       let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
       let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
       let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger nobody
        ifelse (any? ultra-fast-chargers) [
        set available-charger one-of ultra-fast-chargers]
         [
        set available-charger one-of fast-chargers]

        if not any? turtles-on patch-ahead 1  and [patch-type] of patch-ahead 1 = "queue locations"  [
          fd 1 ]


      if not empty? queue2 [
       let next-truck first queue2       ;the next serviced truck is the first truck in queue 2

       let next-charger available-charger

       set time-to-break max list (time-to-break - 1) 0


       ifelse (available-charger = nobody) [
      ; if no charger available
        ask next-truck [
           if (time-to-break = 0) and (break-time < 45) [
            move-to available-parking                    ;ask the truck to move to the parking area for a break if the time-to-break reaches 0 and without a previous break.
            set time-entered-parking current-time
          ifelse time-entered-parking >= time-entered-queue  [set time-in-queue time-entered-parking - time-entered-queue]
             [set time-in-queue 1440 + time-entered-parking - time-entered-queue ]  ;calculate time spent in queue for the truck
            set total-time-in-queue
              (total-time-in-queue + time-in-queue)
            set queue remove self queue          ;remove the truck from queue
            set queue2 remove self queue2        ;remove the truck from queue2
            let length-queue length queue
            set status "break"                   ;set the truck's status to "break"
        ]
     ]
    ]

        [
          ;if a ultral-fast (1MW) charger available
          ifelse member? available-charger ultra-fast-chargers [
          ask next-truck [
          if xcor = 0 [

           ;if the truck has not taken a break before
           ifelse (break-time < 45) [
           move-to available-charger                             ;ask the truck move to the available ultra-fast charger

           set time-entered-service current-time + t-manoeuvring

           ;Assign start-charging-day as the arrival day or the next day after arrival
           if time-entered-service > 1440 [
                set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)
              ]
           if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

          ;calculate time spent in queue for the truck
          if  time-entered-service > 0 and time-entered-queue > 0 [
           ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
              ]

          set total-time-in-queue
              (total-time-in-queue + time-in-queue)
          set queue remove self queue         ;remove the truck from queue
          set queue2 remove self queue2      ;remove the truck from queue2
           set color red
           set status "fast-charging"       ;set the truck's status to "fast-charging"
         ]

            ;if the truck has taken a break before
            [
          move-to available-charger         ;ask the truck move to the available ultra-fast charger

          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)]
         if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

              if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
              ]
          set total-time-in-queue
              (total-time-in-queue + time-in-queue)
           set color red
           set status "charging-until-soc-high"   ;set the truck's status to "charging-until-soc-high"
          set queue remove self queue        ;remove the truck from queue
          set queue2 remove self queue2      ;remove the truck from queue2
            ]
          ]
        ]
      ]


        ;if a fast (350kw) charger available
          [
          ask next-truck [

          if (time-to-break <= time-to-break-max) and  break-time < 45 [

           ; if arrival-soc less than  soc-threshold-low
           if current-soc <= soc-threshold-low [

          move-to available-charger                     ;ask the truck move to the available fast charger
           set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

              if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
              ]                                         ;calculate time spent in queue for the truck
          set total-time-in-queue
              (total-time-in-queue + time-in-queue)
          set queue remove self queue           ;remove the truck from queue
          set queue2 remove self queue2         ;remove the truck from queue2
          set color blue
          set status "charging"                ;set the truck's status to "charging"
          ]]




          if (time-to-break = 0) and break-time < 45 [
            ; if arrival-soc larger than  soc-threshold-low
            if current-soc > soc-threshold-low [

          move-to available-charger
             set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

               ;calculate time spent in queue for the truck
              if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
              ]
          set total-time-in-queue
              (total-time-in-queue + time-in-queue)
          set queue remove self queue                 ;remove the truck from queue
          set queue2 remove self queue2               ;remove the truck from queue2
          set color blue
          set status "opportunity-charging"  ;set the truck's status to "opportunity-charging"
          ]
          ]


          ;if the truck returns to the queue after taking a break
          if break-time >= 45 [

           ;if the arrival-soc is less than  soc-threshold-low
           if current-soc <= soc-threshold-low [
            move-to available-charger                                  ;ask the truck move to the available fast charger

          set time-entered-service current-time + t-manoeuvring

          ;Assign start-charging-day as the arrival day or the next day after arrival
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]


          ;calculate time spent in the queue
          if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
              ]
            set total-time-in-queue
              (total-time-in-queue + time-in-queue)
              set queue remove self queue           ;remove the truck from queue
              set queue2 remove self queue2         ;remove the truck from queue2
              set status "charging-until-soc-low"   ;set the truck's status to "charging-until-soc-low"
          ]]


        ;If the truck has not taken a break and still has a long time until its next break.
         if time-to-break > time-to-break-max [
            if current-soc <= soc-threshold-low [

          move-to available-charger
                        set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
             set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
              if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
              ]
          set total-time-in-queue
              (total-time-in-queue + time-in-queue)
              set queue remove self queue          ;remove the truck from queue
              set queue2 remove self queue2        ;remove the truck from queue
              set status "charging-until-soc-low" ] ;set the truck's status to "charging-until-soc-low"
         ]

        ]


        ]



    ]
  ]
end



; 14 move vehicle to queue procedure
to move-vehicle-to-queue

  set time-entered-queue current-time

  set total-trucks-in-queue (total-trucks-in-queue + 1) ;calculate the total number of trucks in the queue

  ifelse (length queue < (-1 * min-pxcor))[
  ifelse length queue != 0 [

  let last-truck last queue
  let current-xcor [xcor] of last-truck

  ifelse current-xcor > min-pxcor [
  let new-xcor (current-xcor - 1)

   setxy new-xcor 1                 ;calculte the position for the truck who move to the queue
   set queue lput self queue


  ; Move the turtle to the calculated position in the queue
    ]
      [
      stop
      ]

    ]
    [
    let new-xcor 0
    setxy new-xcor 1
    set queue lput self queue
    ]

  show-turtle

  ]
   [
    stop
  ]

end



; Queue vehicles waiting for 1MW chargers into queue1
to create-virtual-queue1
  ; add the truck to queue1
  set queue1 lput self queue1

  check-queue1-real-time

end



; Make vehicles after queue1 queue into queue2
to create-virtual-queue2
  ; add the truck to queue2
  set queue2 lput self queue2

  check-queue2-real-time

end





; 15 check-queue1-real-time procedure
to check-queue1-real-time

       ;check whether there is nay available charger
        let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
        let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
        let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger nobody

        ifelse (any? ultra-fast-chargers) [
           set available-charger one-of ultra-fast-chargers
         ]
         [
         set available-charger one-of fast-chargers
         ]

  foreach queue1 [
    t -> ask t [
           ;if time-to-break of the truck in queue1 reaches 0
           if (time-to-break = 0)  [
           if break-time < 45 [
               ;if there is any available charger
               if (available-charger != nobody) [
                   if member? available-charger fast-chargers [

           move-to available-charger   ;move the truck to the available charger
           set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

           ;calculate time spent in the queue
           if  time-entered-service > 0 and time-entered-queue > 0 [
              ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]

              ]

           set total-time-in-queue
              (total-time-in-queue + time-in-queue)
           set queue remove self queue        ;remove vehicle from queue
           set queue1 remove self queue1      ;remove vehicle from queue1
           set color violet
          ;if arrival-soc is larger than soc-threshold-low
          ifelse arrival-soc > soc-threshold-low [
           set status "opportunity-charging" ]  ;set the truck's status to "opportunity-charging"
              ;if arrival-soc is less than soc-threshold-low
              [
              set status "charging"      ;set the truck's status to "charging"
              ]

     ]

     ]
      ]

  ]]
  ]
end




; 16 check-queue2-real-time procedure
to check-queue2-real-time
        let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
        let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]

        let available-charger nobody

        ifelse (any? ultra-fast-chargers) [
           set available-charger one-of ultra-fast-chargers
         ]
         [
         set available-charger one-of fast-chargers
         ]


  if first queue2 = nobody [
    set queue2 remove-item 0 queue2
   ]

  foreach queue2 [
    t -> ask t [
                 ; if time-to-break of the truck reaches 0 and has not taken a break before
                 if time-to-break = 0 and break-time  < 45 [
                 if available-charger = nobody [

                 let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

                   move-to available-parking     ;move truck to the parking space for a break
                   set time-entered-parking current-time

                  ifelse time-entered-parking >= time-entered-queue [set time-in-queue time-entered-parking - time-entered-queue]
                        [set time-in-queue 1440 + time-entered-parking - time-entered-queue]
                   set total-time-in-queue
                            (total-time-in-queue + time-in-queue)      ;calculate time spent in the queue
                   set queue2 remove self queue2                       ;remove vehicle from queue2
                   set queue remove self queue                          ;remove vehicle from queue
                   set status "break" ]                                ;set the truck's status to "break"

                   ]

        ]
  ]



end



; 17 step-truck procedure
to step-truck ;

     ifelse (current-time >= 6 *  60) and (current-time <= 19 * 60)  [

     if current-time >= time-of-arrival or ((arrival-day < current-day) and (current-time <= time-of-arrival)) [

      if status = "driving" [

       if [patch-type] of patch-ahead 1 = "road" [
        fd 1 ]

      ; Left the simulation?
      if xcor = max-pxcor [ die ]

     ;17-1 model behaviours for case 1,2,3
      if arrival-soc <= soc-threshold-low [
      if xcor = 0 [

        let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
        let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
        let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger nobody

        ifelse (any? ultra-fast-chargers) [
           set available-charger one-of ultra-fast-chargers
         ]
         [
         set available-charger one-of fast-chargers
         ]


        ;mega-watt charging or kilo-watt charging
        ifelse available-charger != nobody [


         ;if mega-watt charging
         ifelse member? available-charger ultra-fast-chargers  [

          if length queue = 0 [
          set time-entered-service current-time + t-manoeuvring

          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
               set start-charging-day (current-day + 1) ]

          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]  ; assign start-charging-day

          set color red
          move-to available-charger     ; truck move to available 1MW charger
          set status "fast-charging" ]  ; set status to "fast-charging'
          ]

          ;if kilo-watt charging

          [
            ; if low charge and also need to take a break immediately
            ifelse time-to-break <= time-to-break-min [
            if length queue2 = 0 [
                            set time-entered-service current-time + t-manoeuvring
            if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                  set start-charging-day (current-day + 1)]

          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]   ;  assign start-charging-day
            move-to available-charger   ; truck move to available 350 kw charger
            set color blue
            set status "charging"  ; set status to "charging'
            ]
            ]

            ; if low charge but no urgent break
            [

            if length queue2 = 0 [
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                  set start-charging-day (current-day + 1)]

          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            move-to available-charger             ; truck move to available 350 kw charger
            set color pink
            set status "charging-to-soc-low"  ]   ; set status to "charging-to-soc-low'
            ]
          ]
        ]

        ; if no charger available
        [

          let ratio-queue-to-fast length queue / num-ultra-fast-chargers
             ;if the queue length is less than or equal to the number of 1 MW chargers.
             ifelse ratio-queue-to-fast <= 1 [
             move-vehicle-to-queue                ; truck decide to join the queue
             create-virtual-queue1
             set color violet
             set status "waiting-for-fast-chargers"  ; set status "waiting-for-fast-chargers"
             ]
            ;if the queue length is larger than the number of 1 MW chargers.
            [
             move-vehicle-to-queue            ; truck decide to join the queue
             create-virtual-queue2
             set status "queuing-for-charging-or-parking" ; set status "queuing-for-charging-or-parking"

         ]
    ]

       ; if time-to-break reaches 0 upon arrival and no charger available
        if time-to-break = 0 and  available-charger = nobody [

          move-to available-parking        ; truck moves to the parking space
          set queue remove self queue
          set time-entered-parking current-time
          set status "break"                 ; set status "break"

        ]


    ]
  ]



      ;17-2 model behaviours for case 4,7
              if time-to-break <= time-to-break-min [

              if xcor = 0 and arrival-soc > soc-threshold-low [

              let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
              let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
              let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

              let available-charger nobody

             ifelse (any? ultra-fast-chargers) [
            set available-charger one-of ultra-fast-chargers
            ]
           [
            set available-charger one-of fast-chargers
            ]


             if available-charger != nobody [
              ; if 1mW charger available
              ifelse member? available-charger ultra-fast-chargers  [

               ; no vehicle queuing
                ifelse length queue = 0 [
               set time-entered-service current-time + t-manoeuvring
                 if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
               if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

                set color red
                move-to available-charger     ;trucks moves to the available 1MW charger
                set status "fast-charging"]   ;set status "fast-charging"

              ; if there are trucks in the queue
              [
                   move-to available-parking       ;trucks moves to the parking space
                   set time-entered-parking current-time
                   set status "break"              ;set status "break"
              ]

              ]

               ;if 350 kw charger available
                [
                 ; if length of the queue is less than or equal to the number of fast cahrgers
                ifelse length queue <= num-ultra-fast-chargers + 1 [
              set time-entered-service current-time + t-manoeuvring
              if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
              if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
                  move-to available-charger           ;trucks moves to the available 350kw charger
                  set color blue
                  set status "opportunity-charging"]  ;set status "opportunity-charging"

                [
                   move-to available-parking         ;trucks moves to the parking space
                   set time-entered-parking current-time
                   set status "break"                ;set status "break"

                ]

                ]

             ]


           ; if no charger available
           if available-charger = nobody [
               let ratio-queue-to-fast length queue / num-ultra-fast-chargers
                   ifelse ratio-queue-to-fast = 0 [  ;if there is no truck in the queue
                     move-vehicle-to-queue    ;trucks moves to the queue
                     create-virtual-queue1
                     set color violet
                     set status "waiting-for-fast-chargers";  ;;set status "waiting-for-fast-chargers"
                   ]

                   [
                   move-to available-parking             ;trucks moves to the parking space
                   set time-entered-parking current-time
                   set status "break"              ;set status "break"

                   ]
               ]

              ]


             ]




    ;17-3 model behaviours for case 5, 8
   if arrival-soc > soc-threshold-low [

      if xcor = 0 and (time-to-break > time-to-break-min) and (time-to-break <= time-to-break-max)   [
         ;set color brown

         let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
         let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
         let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

         let available-charger one-of ultra-fast-chargers

         let ratio-queue-to-fast length queue / num-ultra-fast-chargers


         ifelse available-charger != nobody [

             ; no vehicle queuing
             if length queue = 0 [
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
             set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
                set color red
             move-to available-charger        ;truck move to available 1MW charger
             set status "fast-charging"]       ;set statusto 'fast-charging'

           ]

            ; if no charger available
             [
            ifelse arrival-soc <  soc-threshold-high [

               ifelse ratio-queue-to-fast <= 1  [  ; if length of queue is not larger than the number of 1MW chargers
               move-vehicle-to-queue
               create-virtual-queue1
               set color violet
               set status "waiting-for-fast-chargers"  ;set status to "waiting-for-fast-chargers"
                ]
               ;if queue length is larger than the number of 1MW chargers
               [
               set status "leave"   ;set status to "leave"
                 ]
            ]
           ;if arrival-soc is larger than   soc-threshold-high
            [
              set status "leave" ;set status to "leave"
            ]

            ]
        ]

  ]



     ;17-4 model behaviours for case 6
     if time-to-break > time-to-break-max [

      if xcor = 0 and (arrival-soc > soc-threshold-low) and (arrival-soc < soc-threshold-high)   [


         let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
         let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
         let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

         let available-charger nobody

        ifelse (any? ultra-fast-chargers) [
       set available-charger one-of ultra-fast-chargers
       ]
      [
       set available-charger one-of fast-chargers
       ]

      ; Check if the queue is not empty and there is an available charger
         if available-charger != nobody [
         ; if mega-watt charger available
          ifelse member? available-charger ultra-fast-chargers  [
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
             set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
                move-to available-charger                       ;truck move to available 1MW charger
            set color red
            set status "opportunity-charging-until-soc-high"       ;set status to "opportunity-charging-until-soc-high"
             ]
             ; if no mega-watt charger available
             [
            set status "leave"          ; set status to "leave"
            ]
      ]
      ]
    ]


  ]

  ]

]


  ;overnight charging
  [
    ;if arrival-time is between 7pm and 6am the next day
    if current-time >= time-of-arrival or ((arrival-day < current-day) and (current-time <= time-of-arrival)) [

    if status = "driving" [

       if [patch-type] of patch-ahead 1 = "road" [
        fd 1 ]

      ; Left the simulation?
      if xcor = max-pxcor [ die ]

      let slow-chargers patches with [ not any? other turtles-here and (patch-type = "slow charger")]
      let available-charger nobody

      if (any? slow-chargers) [
            set available-charger one-of slow-chargers ]

      if xcor = 0 [

      ifelse available-charger != nobody [
         if arrival-soc < soc-threshold-high [

         move-to available-charger        ; if any slow-charger available
         set time-entered-service current-time + t-manoeuvring
         set status "slow-charging"        ; set status "slow-charging`'

      ]
      ]

      ; if arrival-time is outside the overnight charging period
      [
          nine-cases-charging

            ]

    ]

    ]

    ]

  ]


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   ; 17-5 slow-charging status

    if status = "slow-charging" [

  ; calculate charging time
    if time-entered-service > 19 * 60 [

      if current-day = arrival-day and current-time >= time-entered-service [
        set charging-time-p1 current-time - time-entered-service ]

      if current-day = arrival-day + 1 [
        set charging-time-p2 current-time
      ]

     set charging-time (charging-time-p1 + charging-time-p2)

    ]

    if time-entered-service < 6 * 60 and current-time >= time-entered-service [

     set charging-time current-time - time-entered-service

    ]

    ;update current soc when charging
      let max-charge-power [ max-power ] of patch-here
      let charge-power nobody

      ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
      set charge-power max-charge-power
      ]
      [
      set charge-power max-charge-power * 0.5
      ]

     let energy-delivered charge-power * (mins-per-tick / 60)

     if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]

   ; if slow-charging for 9 hours
    if charging-time >= 9 * 60 [
      set color white
      set status "leave"   ;set status "leave"
    ]

  ]


; 17-6 charging-to-soc-low status
  if status = "charging-to-soc-low" [



       let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
       let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
       let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

       let ratio-queue-to-fast length queue / num-ultra-fast-chargers

       let available-charger nobody


        ifelse (any? ultra-fast-chargers) [
       set available-charger one-of ultra-fast-chargers
       ]
      [
       set available-charger one-of fast-chargers
       ]

     ; calculate charging time
    if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]



  ;update current soc when charging

      let max-charge-power [ max-power ] of patch-here
      let charge-power nobody

      ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
         set charge-power max-charge-power
         ]
         [
         set charge-power max-charge-power * 0.5
         ]

      let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]



       set time-to-break max list (time-to-break - 1) 0

       if current-soc >= soc-threshold-low [

             ;if the truck needs to take break immediately then this truck's case swithc to case 4
            if time-to-break <= time-to-break-min [
            set color yellow
            set status "charging" ]


          ;if break is not urgent then this truck's case swithc to case 4
          if time-to-break <= time-to-break-max and time-to-break > time-to-break-min [
          if current-soc < soc-threshold-high [

          ifelse available-charger != nobody [

         ; if 1MW charger available
          ifelse member? available-charger ultra-fast-chargers  [

          ifelse length queue = 0 [
            set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
               set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            move-to available-charger     ;move to available 1MW charger
            set color red
            set status "fast-charging"]   ; set status to "fast-charging"

              [
              ;if the length of the queue is not greater than the number of 1MW chargers
              ifelse ratio-queue-to-fast <= 1  [
               move-vehicle-to-queue   ;truck move to the queue
               create-virtual-queue1
               set color pink
               set status "waiting-for-fast-chargers"  ;the truck waits for 1MW chargers
                ]

              ;if the length of the queue is  greater than the number of 1MW chargers

               [
               set time-to-leave current-time
              if arrival-soc != soc-threshold-low [

                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]
                set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

                set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
                set color white
                set status "leave"]   ;truck leaves the service station
               ]

              ]
            ]
            ; if 350 kw charger available
            [
             ifelse ratio-queue-to-fast <= 1  [   ;if length of the queue is not greater than the number of the 1MW chargers
               move-vehicle-to-queue              ;truck moves to the queue
               create-virtual-queue1
               set color pink
               set status "waiting-for-fast-chargers"   ;truck waits for the 1MW charger
                ]

              ;if length of the queue is greater than the number of the 1MW chargers
               [
                set time-to-leave current-time

               if arrival-soc != soc-threshold-low [
                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]
                set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

                set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)

                set color white
                  set status "leave" ]   ; truck leaves the service station
                 ]

            ]

            ]

          ; if no charger available
          [

          ifelse ratio-queue-to-fast <= 1  [    ; if length of the queue is not greater than the number of the 1MW chargers
               move-vehicle-to-queue            ;truck moves to the queue
               create-virtual-queue1
               set color pink
               set status "waiting-for-fast-chargers"  ;truck waits for 1MW chargers
                ]

            ;if length of the queue is greater than the number of the 1MW chargers, truck leave the service station
               [
                set time-to-leave current-time
                if arrival-soc != soc-threshold-low [

                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]

                set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

                set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)

              set color white
                set status "leave"]
                 ]

          ]

        ]
      ]






      ;if it has a long time to next break the the truck become case 6
       if time-to-break > time-to-break-max and current-soc < soc-threshold-high [


         ifelse available-charger != nobody [

          ifelse member? available-charger ultra-fast-chargers  [

          ifelse length queue = 0 [

          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
             set start-charging-day (current-day + 1) ]
         if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
              move-to available-charger
            set color red
            set status "switch-to-fast-charging"]
            [
            set time-to-leave current-time

            if arrival-soc != soc-threshold-low [

            ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]
            set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

            set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
            set color white
                set status "leave"]
            ]
             ]

             [
            set time-to-leave current-time

             if arrival-soc != soc-threshold-low [

                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]
            set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

            set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
            set color white
              set status "leave"]
            ]
            ]
          [
          set time-to-leave current-time

          if arrival-soc != soc-threshold-low [

                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]

          set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
          set color white
            set status "leave"]
          ]

    ]


  ]

  ]


    ; 17-7 opportunity-charging-until-soc-high status
    if status = "opportunity-charging-until-soc-high" [


 ;calculate charging time
     if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]

      ;update current soc when charging
          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]

        ; truck leaves the service station if currentsoc is larger than soc-threshold-high
        if current-soc >= soc-threshold-high [

        set time-to-leave current-time

        set color white
        set status "leave"

       ;calculate time 'wasted' while charging
        ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
          [ if time-to-leave != 0 [
            set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
            ]

          ]
        set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

        set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)

        ]
  ]


 ; 17-8 opportunity-charging status
 if status = "opportunity-charging" [

      ;calculate charging time
      if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]


     ;update current soc when charging
        let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
        let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
        let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger one-of ultra-fast-chargers


          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]




      if (current-soc >= soc-threshold-high) [

          if (current-soc <= soc-threshold-high + 2) and charging-time < 45
           [
          set time-complete-service current-time
           ]
        ;truck leaves the charging station if charging for 45mins
        if charging-time >= 45 [

        set time-to-leave current-time
        set color white
        set status "leave"


      ifelse time-complete-service != 0 [

      ifelse time-to-leave > time-complete-service [set extra-time-on-chargers time-to-leave - time-complete-service]
          [set extra-time-on-chargers time-to-leave + 1440 - time-complete-service]
        set total-extra-time-on-chargers  (total-extra-time-on-chargers + extra-time-on-chargers)
          set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]
        [
          set total-extra-time-on-chargers  (total-extra-time-on-chargers + charging-time)
          set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]


        ]

      ]

      ;if current soc is less than soc-threshold-high after charging 45mins
      if (charging-time >= 45) and (current-soc < soc-threshold-high) [

         ifelse available-charger != nobody [
          set time-entered-service current-time + t-manoeuvring

          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
          set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ] ; assign start-charging-day
             move-to available-charger
             set status "switch-to-fast-charging"   ;switch to a 1MW charger if any available
           ]
        [
        set color white
        set status "leave"]  ; truck leaves the service station if no 1MW charger available
         ]
    ]




 ; 17-9 fast-charging status
    if status = "fast-charging" [
     ;calculate charging time
     if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]

         ;update current soc
          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

    if (charging-time > 0) [
      set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
    ]


    ifelse break-time >= 45   ;if fast-charging after taking a break
    [
      set status "charging-until-soc-high"

    ]

    [



      if (current-soc >= soc-threshold-high) [

          if (current-soc <= soc-threshold-high + 2) and charging-time < 45
           [
          set time-complete-service current-time
           ]

        ; truck leave the station if charging for 45mins
        if charging-time >= 45 [

        set time-to-leave current-time
        set color white
        set status "leave"

          ifelse time-complete-service != 0 [

         ifelse time-to-leave > time-complete-service [set extra-time-on-chargers time-to-leave - time-complete-service]
          [set extra-time-on-chargers time-to-leave + 1440 - time-complete-service]
          set total-extra-time-on-chargers  (total-extra-time-on-chargers + extra-time-on-chargers)
            set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]
          [

          set total-extra-time-on-chargers  (total-extra-time-on-chargers + charging-time)
          set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]
          ]
         ]
       ]
    ]


 ; 17-10 charging status

     if status = "charging" [


        let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
        let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
        let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger nobody

       ifelse (any? ultra-fast-chargers) [
           set available-charger one-of ultra-fast-chargers
         ]
         [
         set available-charger one-of fast-chargers
         ]

         let real-time ticks

; calculate charging time
        if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]
      ; update current-soc while charging
          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]


      if (current-soc >= soc-threshold-high) [

          if (current-soc <= soc-threshold-high + 2) and charging-time < 45
           [
          set time-complete-service current-time
           ]

        if charging-time >= 45 [

        set time-to-leave current-time
        set color white
        set status "leave"        ;truck leaves the service station after charging for 45mins

        ;Calculate extra time spent on the chargers when current SOC is larger than soc-threshold-high.
        ifelse time-complete-service != 0 [

        ifelse time-to-leave > time-complete-service [set extra-time-on-chargers time-to-leave - time-complete-service]
          [set extra-time-on-chargers time-to-leave + 1440 - time-complete-service]

        set total-extra-time-on-chargers  (total-extra-time-on-chargers + extra-time-on-chargers)
          set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]
        [

        set total-extra-time-on-chargers  (total-extra-time-on-chargers + charging-time)
        set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)

        ]

      ]

       ]



    ; if current-soc is less than soc-threshold-high after charging for 45mins
    if (charging-time >= 45) and (current-soc < soc-threshold-high)  [


        if current-soc > soc-threshold-low [      ;if current-soc is larger than soc-threshold-low
        ;if no charger is available
        ifelse available-charger != nobody [
            ifelse member? available-charger ultra-fast-chargers  [
             move-to available-charger
                      set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)
            ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
              set status "switch-to-fast-charging" ]     ; if 1MW charger available, the truck move to the 1MW charger
          ;if 350 kw charger is available
          [

              set color white
              set status "leave"
            ]
          ]
         ;if no charger is available
          [
            set color white
            set status "leave"
          ]
        ]



      if current-soc <= soc-threshold-low [   ;if current-soc is less than soc-threshold-low

         ifelse available-charger != nobody [
            ifelse member? available-charger ultra-fast-chargers  [
            move-to available-charger

          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
           set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            set status "switch-to-fast-charging" ]
              [

            set status "charging-until-soc-low"
              ]
             ]
          [

            set status "charging-until-soc-low"

        ]

      ]
    ]

  ]







  if status = "leave" [

        let nearest-road patch min (list num-ultra-fast-chargers num-fast-chargers num-slow-chargers) 0

        if not any? turtles-on nearest-road [
          move-to nearest-road
          set status "driving"
          ]
      ]

; 17-11 switch-to-fast-charging status

 if status = "switch-to-fast-charging" [
         let real-time ticks
  ; calculate charging time
        if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]
      ; update current-soc while charging
          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
           set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max ]


        if (current-soc >= soc-threshold-high ) [         ;if current-soc is larger than soc-threshold-high
          set time-to-leave current-time
          set color white
          set status "leave"                     ; the truck leaves the service station

      ;calculate time "wasted"while charging
        ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
         [ if time-to-leave != 0 [
           set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
           ]

         ]
          set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)

]

  ]





 ; 17-12 break status
    if status = "break" [
     let real-time ticks

    ifelse current-time >= time-entered-parking [set break-time current-time - time-entered-parking ] [set break-time 1440 - time-entered-parking + current-time ]

    let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
    let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
    let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

     let available-charger nobody
     ifelse (any? ultra-fast-chargers) [
     set available-charger one-of ultra-fast-chargers]
      [
     set available-charger one-of fast-chargers]

    if break-time >= 45 [

      set status "charging-after-break"   ;status switch to "charging-after-break" after taking a 45mins break

    ]

  ]





 ; 17-13 charging-after-break status

 if status = "charging-after-break" [

    let real-time ticks
    ifelse current-time >= time-entered-parking [set break-time current-time - time-entered-parking] [set break-time 1440 - time-entered-parking + current-time ]


       let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
       let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
       let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger nobody
        ifelse (any? ultra-fast-chargers) [
        set available-charger one-of ultra-fast-chargers]
         [
        set available-charger one-of fast-chargers]

        if not any? turtles-on patch-ahead 1  and [patch-type] of patch-ahead 1 = "queue locations"  [
          fd 1 ]


       let ratio-queue-to-fast length queue / num-ultra-fast-chargers
       ;if the length of queue is not greater than the number of 1MW chagers
       ifelse ratio-queue-to-fast <= 1 [

        ifelse (available-charger != nobody) [
        ifelse member? available-charger ultra-fast-chargers [  ;if 1MW charger available

          if current-soc <= soc-threshold-low [                 ; if current-soc is less than soc-threshold-low
          ifelse length queue = 0 [
          move-to available-charger
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
             set color red
            set status "charging-until-soc-high"           ;set status to "charging-until-soc-high"
         ]
         [
          move-vehicle-to-queue                            ;truck moves to the queue
          create-virtual-queue1
          set color violet
          set status "waiting-for-fast-chargers"           ;the truck waits for 1MW charger
         ]
        ]

        ; if current -soc is greater than soc-threshold-low
        if current-soc > soc-threshold-low [
          ifelse length queue = 0 [
            move-to available-charger              ;the truck moves to the available charger if there is no vehicle in the queue
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)]
         if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            set color red
            set status "charging-until-soc-high"    ;set status to "charging-until-soc-high"
         ]

         [

              set color white
              set status "leave"      ;the truck leave the sevice station if the length of queue is larger than 0
         ]
        ]


      ]
      ; if 350 kw charger available
      [
         ifelse current-soc <= soc-threshold-low [
          move-vehicle-to-queue
          create-virtual-queue1
          set color violet
            set status "waiting-for-fast-chargers" ]
          [
          set color white
            set status "leave"
          ]


      ]
      ]

    ; if no charger is available
      [ifelse current-soc <= soc-threshold-low [  ;if current-soc is less than soc-threshold-low
          move-vehicle-to-queue       ;the truck moves to queue1
          create-virtual-queue1
          set color violet
        set status "waiting-for-fast-chargers"] ;the truck waits for 1MW charger

        ;if current-soc is larger than soc-threshold-low
        [
         set color white
          set status "leave"
        ]


    ]
    ]

; if the length of queue is greater than the number of 1MW chargers
   [

     ifelse current-soc <= soc-threshold-low [

          move-vehicle-to-queue      ;truck moves to the queue as current-soc <= soc-threshold-low
          create-virtual-queue2
        set color green
       set status "queuing-for-charging-or-parking"

      ]

      [
      set color white
        set status "leave"      ;truck leaves the service station as current-soc is larger than soc-threshold-low
      ]

  ]


  ]


 ; 17-14 charging-until-soc-low status

 if status = "charging-until-soc-low" [

         let real-time ticks
     ;calculate charging time
      if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]

     ;update current soc while charging
          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]


      if current-soc >= soc-threshold-low [ ;if current-soc is larger than soc-threshold-low

         set color white
         set status "leave"   ;truck leaves the service station
         set time-complete-service current-time


       ;if charging after break, calculate time 'wasted' while charging
      if break-time >= 45 [

        if arrival-soc != soc-threshold-low [

         set time-charging-not-on-break time-complete-service - time-entered-service

         set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

         set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
      ]
      ]


     if time-to-break > time-to-break-max and charging-time < 45 [

      if arrival-soc != soc-threshold-low [
         set time-charging-not-on-break time-complete-service - time-entered-service

         set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)]
      ]


     if charging-time >= 45 [

        if arrival-soc != soc-threshold-low [
         set time-charging-not-on-break time-complete-service - time-entered-service - 45

         set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)]
      ]

      ]



  ]


 ; 17-15 charging-until-soc-high status
  if status = "charging-until-soc-high" [

     ;calculate charging time
       let real-time ticks

       if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]

      ; update current soc while charging
          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]

    ; if soc is larger than  soc-threshold-high
      if current-soc >= soc-threshold-high [
      set time-complete-service current-time
      set color white
      set status "leave"   ;truck leave the station

      ;if charging after break
      if break-time >= 45 [

      ;calculate the time "wasted" while charging
      if arrival-soc < soc-threshold-high [
          set time-charging-not-on-break charging-time
        ]

      set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)
          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1) ]
      ]

      ]








 ; 17-16 waiting-for-fast-chargers status

if status = "waiting-for-fast-chargers" [

     if not any? turtles-on patch-ahead 1  and [patch-type] of patch-ahead 1 = "queue locations"  [
       fd 1 ]

   set time-to-break max list (time-to-break - 1) 0
   let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
   let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
   let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

   let available-charger nobody

    ifelse (any? ultra-fast-chargers) [
           set available-charger one-of ultra-fast-chargers
         ]
         [
         set available-charger one-of fast-chargers
         ]

 ; If there are trucks waiting for 1 MW chargers, trucks follow a first-come, first-served policy in the queue.
   if not empty? queue1 [
       let next-truck first queue1   ;The next served truck is the first truck in queue 1

       let next-charger available-charger

       set time-to-break max list (time-to-break - 1) 0

      ifelse (available-charger != nobody) [

      ifelse member? available-charger ultra-fast-chargers [    ; if 1MW charger is available
          ask next-truck
          [ move-to available-charger                           ;truck moves to the available charger
          ; assign start-chargingday
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
            set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

          ;calculate time spent in queue
          if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
            ]
          set total-time-in-queue
              (total-time-in-queue + time-in-queue)

          set queue remove self queue          ;remove the truck from the queue
          set queue1 remove self queue1        ;remove the truck from the queue1
          set color red
          set status "fast-charging"           ; set status to "fast-charging"
        ]
        ]

        ;if 350 kw charger available
      [


         ask next-truck [
            ; if time-to-break of the truck in queue1 reaches 0 and the truck has not taken a break before
            if time-to-break = 0 and (break-time < 45) [
              ifelse current-soc > soc-threshold-low [ ;if current-soc is larger than soc-threshold-low
              move-to available-charger                ;the truck moves to the 350kw charger

                ;assign start-charging-day
             set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

          ;calculate tiem spent in queue for the truck
          if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
                ]
              set total-time-in-queue
                  (total-time-in-queue + time-in-queue)

              set queue remove self queue       ;remove the truck from the queue
              set queue1 remove self queue1      ;remove the truck from the queue1

          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
                set color blue
                set status "opportunity-charging"]       ;set status to "opportunity-charging"

              ;if current-soc is less than soc-threshold-low
              [
              move-to available-charger     ;the truck moves to the 350kw charger

          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
               set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
          if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
                ]
              set total-time-in-queue
                  (total-time-in-queue + time-in-queue)

              set queue remove self queue      ;remove the truck from the queue
              set queue1 remove self queue1    ;remove the truck from the queue1

          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
                set color blue
              set status "charging"     ;set status to "charging"

              ]
          ]
          ]
    ]

    ]



    ; if no charger is available
    [
         ask next-truck [
          if time-to-break = 0 and (break-time < 45)  [
            move-to available-parking        ;the truck moves to the parking space

           ;calculate time spent in the queue
           set time-entered-parking current-time
           ifelse time-entered-parking >= time-entered-queue [set time-in-queue time-entered-parking - time-entered-queue]
            [set time-in-queue 1440 + time-entered-parking - time-entered-queue]

           set total-time-in-queue
              (total-time-in-queue + time-in-queue)

           set queue remove self queue       ;remove the truck from queue
           set queue1 remove self queue1     ;remove the truck from queue1
           set time-entered-parking current-time
           set status "break"                 ; set status to "break"

    ]

  ]

  ]
    ]
  ]



if status = "queuing-for-charging-or-parking"[

    if not any? turtles-on patch-ahead 1  and [patch-type] of patch-ahead 1 = "queue locations"  [
          fd 1 ]     ; The truck moves one step forward in the queue if there is no truck ahead.
    begin-service
  ]



end



; 18 nine-cases-charging procedure
to nine-cases-charging

     ;case 1,2,3
      if arrival-soc <= soc-threshold-low [

      if xcor = 0 [

        let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
        let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
        let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger nobody

        ifelse (any? ultra-fast-chargers) [
           set available-charger one-of ultra-fast-chargers
         ]
         [
         set available-charger one-of fast-chargers
         ]


        ;mega-watt charging or kilo-watt charging
        ifelse available-charger != nobody [

         ifelse member? available-charger ultra-fast-chargers  [

          if length queue = 0 [
          ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
                          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
               set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
          set color red
          move-to available-charger
          set status "fast-charging" ]
          ]
          [

            ifelse time-to-break <= time-to-break-min [
            if length queue2 = 0 [
            ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
                            set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                  set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            move-to available-charger
            set color blue
            set status "charging"
            ]
            ]

            [

            if length queue2 = 0 [
            ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                  set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            move-to available-charger
            set color pink
            set status "charging-to-soc-low"  ]
            ]
          ]
        ]


        [

          let ratio-queue-to-fast length queue / num-ultra-fast-chargers
             ifelse ratio-queue-to-fast <= 1 [
             move-vehicle-to-queue
             create-virtual-queue1
             set color violet
             set status "waiting-for-fast-chargers"
             ]
            [
             move-vehicle-to-queue
             create-virtual-queue2
             ;set num-vehicle-before length queue
             set status "queuing-for-charging-or-parking"

         ]
    ]


        if time-to-break = 0 and  available-charger = nobody [

          move-to available-parking
          set queue remove self queue
          set time-entered-parking current-time
          set status "break"

        ]


    ]
  ]





      ;case 4, 7
       ;case 4, 7
              if time-to-break <= time-to-break-min [

              if xcor = 0 and arrival-soc > soc-threshold-low [
              set color cyan

              ;set color violet
              let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
              let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
              let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

              let available-charger nobody

             ifelse (any? ultra-fast-chargers) [
            set available-charger one-of ultra-fast-chargers
            ]
           [
            set available-charger one-of fast-chargers
            ]

            ;print (word "truck " truck)
            ;print (word "available charger " available-charger)
           ; Check if the queue is not empty and there is an available charger
             if available-charger != nobody [

              ifelse member? available-charger ultra-fast-chargers  [

                ; no vehicle queuing
                ifelse length queue = 0 [
                ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
           set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
                set color red
                move-to available-charger
                set status "fast-charging"]

              [
                   move-to available-parking
                   set time-entered-parking current-time
                   set status "break"
              ]

              ]

                [
                  ifelse length queue <= num-ultra-fast-chargers + 1 [
                  ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
            set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
                  move-to available-charger
                  set color blue
                  set status "opportunity-charging"]
                [
                   move-to available-parking
                   set time-entered-parking current-time
                   set status "break"

                ]

                ]

             ]



           if available-charger = nobody [
               let ratio-queue-to-fast length queue / num-ultra-fast-chargers
                   ifelse ratio-queue-to-fast = 0 [
                    ;print(word "ratio " ratio-queue-to-fast)
                     move-vehicle-to-queue
                     create-virtual-queue1
                     set color violet
                     set status "waiting-for-fast-chargers";
                   ]

                   [
                   move-to available-parking
                   set time-entered-parking current-time
                   set status "break"

                   ]
               ]

;            if available-charger = nobody and time-to-break >= 0 and length queue != 0 [
;            ;set color yellow
;            move-to available-parking
;            set queue remove self queue
;            set queue1 remove self queue1
;            set time-entered-parking current-time
;            set status "break"
;            ]

              ]


             ]









    ;case 5，8
   if arrival-soc > soc-threshold-low [

      if xcor = 0 and (time-to-break > time-to-break-min) and (time-to-break <= time-to-break-max)   [
         ;set color brown

         let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
         let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
         let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

         let available-charger one-of ultra-fast-chargers

         let ratio-queue-to-fast length queue / num-ultra-fast-chargers


         ifelse available-charger != nobody [

             ; no vehicle queuing
             if length queue = 0 [
             ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
             set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
             set color red
             move-to available-charger
             set status "fast-charging"]

           ]

             [
            ifelse arrival-soc <  soc-threshold-high [

               ifelse ratio-queue-to-fast <= 1  [
               move-vehicle-to-queue
               create-virtual-queue1
               set color violet
               set status "waiting-for-fast-chargers"
                ]
               [
               set status "leave"
                 ]
            ]
            [
              set status "leave"
            ]



            ]
        ]

  ]









     ;case 6
     if time-to-break > time-to-break-max [

      if xcor = 0 and (arrival-soc > soc-threshold-low) and (arrival-soc < soc-threshold-high)   [

         ;set color cyan
         let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
         let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
         let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

         let available-charger nobody

        ifelse (any? ultra-fast-chargers) [
       set available-charger one-of ultra-fast-chargers
       ]
      [
       set available-charger one-of fast-chargers
       ]

      ; Check if the queue is not empty and there is an available charger
         if available-charger != nobody [

          ifelse member? available-charger ultra-fast-chargers  [

            ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
             set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            move-to available-charger
            set color red
            set status "opportunity-charging-until-soc-high"
             ]
             [
            set status "leave"
            ]
      ]
      ]
    ]




  if status = "charging-to-soc-low" [



       let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
       let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
       let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

       let ratio-queue-to-fast length queue / num-ultra-fast-chargers

       let available-charger nobody


        ifelse (any? ultra-fast-chargers) [
       set available-charger one-of ultra-fast-chargers
       ]
      [
       set available-charger one-of fast-chargers
       ]


    if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]





      let max-charge-power [ max-power ] of patch-here
      let charge-power nobody

      ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
         set charge-power max-charge-power
         ]
         [
         set charge-power max-charge-power * 0.5
         ]

      let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]



       set time-to-break max list (time-to-break - 1) 0

       if current-soc >= soc-threshold-low [

             ;become case 4
            if time-to-break <= time-to-break-min [
            set color yellow
            set status "charging" ]


          ;become case 5
          if time-to-break <= time-to-break-max and time-to-break > time-to-break-min [
          ;set color violet

          if current-soc < soc-threshold-high [

          ifelse available-charger != nobody [

          ifelse member? available-charger ultra-fast-chargers  [

          ifelse length queue = 0 [
            ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
            set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
               set start-charging-day (current-day + 1) ]
           if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            move-to available-charger
            set color red
            ;set status "opportunity-charging-until-soc-high"
            set status "fast-charging"]
              [

              ifelse ratio-queue-to-fast <= 1  [
               move-vehicle-to-queue
               create-virtual-queue1
               set color pink
               set status "waiting-for-fast-chargers"
                ]
               [
                set time-to-leave current-time


              if arrival-soc != soc-threshold-low [

                ;set time-charging-not-on-break time-to-leave - time-entered-service
                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]
                set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

                set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
                set color white
                set status "leave"]
               ]

              ]
            ]

            [
             ifelse ratio-queue-to-fast <= 1  [
               move-vehicle-to-queue
               create-virtual-queue1
               set color pink
               set status "waiting-for-fast-chargers"
                ]
               [
                set time-to-leave current-time

               if arrival-soc != soc-threshold-low [
                ;set time-charging-not-on-break time-to-leave - time-entered-service
                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]
                set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

                set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)

                set color white
                  set status "leave" ]
                 ]

            ]

            ]

          [

          ifelse ratio-queue-to-fast <= 1  [
               move-vehicle-to-queue
               create-virtual-queue1
               set color pink
               set status "waiting-for-fast-chargers"
                ]
               [
                set time-to-leave current-time
                if arrival-soc != soc-threshold-low [

                ;set time-charging-not-on-break time-to-leave - time-entered-service
                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]



                set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

                set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)

              set color white
                set status "leave"]
                 ]

          ]

        ]
      ]






      ;become case 6
       if time-to-break > time-to-break-max and current-soc < soc-threshold-high [


         ifelse available-charger != nobody [

          ifelse member? available-charger ultra-fast-chargers  [

          ifelse length queue = 0 [
            ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring];;;;;;;;;;;;
                        set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
             set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            move-to available-charger
            set color red
            set status "switch-to-fast-charging"]
              ;set status "opportunity-charging-until-soc-high"]
            [
            set time-to-leave current-time

            if arrival-soc != soc-threshold-low [
            ;set time-charging-not-on-break time-to-leave - time-entered-service

            ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]
            set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

            set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
            set color white
                set status "leave"]
            ]
             ]

             [
            set time-to-leave current-time

             if arrival-soc != soc-threshold-low [
            ;set time-charging-not-on-break time-to-leave - time-entered-service

                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]
            set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

            set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
            set color white
              set status "leave"]
            ]
            ]
          [
          set time-to-leave current-time

          if arrival-soc != soc-threshold-low [
          ;set time-charging-not-on-break time-to-leave - time-entered-service

                ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
                [ if time-to-leave != 0 [
                  set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
                  ]

                ]

          set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
          set color white
            set status "leave"]
          ]

    ]


  ]

  ]




    if status = "opportunity-charging-until-soc-high" [

         ;let real-time ticks
         ;ifelse time-entered-service < current-time [set charging-time max list (current-time - time-entered-service) 0][ set charging-time current-time - time-entered-service]
    if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]




          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]

      ;set color scale-color white current-soc soc-min soc-max

        if current-soc >= soc-threshold-high [

        set time-to-leave current-time

        set color white
        set status "leave"

        ;set time-charging-not-on-break time-to-leave - time-entered-service

          ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
          [ if time-to-leave != 0 [
            set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
            ]

          ]
        set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

        set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)




        ]
  ]



 if status = "opportunity-charging" [

         ;let real-time ticks
         ;ifelse (ticks < 1440) [set charging-time max list (ticks - time-entered-service) 0]

        ;ifelse time-entered-service < current-time [set charging-time max list (current-time - time-entered-service) 0][ set charging-time current-time - time-entered-service]

      if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]



        let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
        let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
        let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger one-of ultra-fast-chargers


          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]




      if (current-soc >= soc-threshold-high) [

          if (current-soc <= soc-threshold-high + 2) and charging-time < 45
           [
          set time-complete-service current-time
           ]

          if charging-time >= 45 [

        set time-to-leave current-time
        set color white
        set status "leave"


        ifelse time-complete-service != 0 [

        ;set extra-time-on-chargers time-to-leave - time-complete-service
      ifelse time-to-leave > time-complete-service [set extra-time-on-chargers time-to-leave - time-complete-service]
          [set extra-time-on-chargers time-to-leave + 1440 - time-complete-service]
        set total-extra-time-on-chargers  (total-extra-time-on-chargers + extra-time-on-chargers)
          set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]
        [
          set total-extra-time-on-chargers  (total-extra-time-on-chargers + charging-time)
          set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]


        ]

      ]






      if (charging-time >= 45) and (current-soc < soc-threshold-high) [

         ifelse available-charger != nobody [
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
          set start-charging-day (current-day + 1)]
        if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

             move-to available-charger
             set status "switch-to-fast-charging"
           ][
        set color white
        set status "leave"]
         ]
    ]





    if status = "fast-charging" [

         ;let real-time ticks
         ; ifelse time-entered-service < current-time [set charging-time max list (current-time - time-entered-service) 0][ set charging-time current-time - time-entered-service]

        if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]

          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

    if (charging-time > 0) [
      set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
    ]


      ;set color scale-color white current-soc soc-min soc-max
    ifelse break-time >= 45
    [

      set status "charging-until-soc-high"


    ]

    [



      if (current-soc >= soc-threshold-high) [

          if (current-soc <= soc-threshold-high + 2) and charging-time < 45
           [
          set time-complete-service current-time
           ]

          if charging-time >= 45 [

        set time-to-leave current-time
        set color white
        set status "leave"

          ifelse time-complete-service != 0 [

         ;set total-extra-time-on-chargers  (total-extra-time-on-chargers + time-to-leave - time-complete-service)
        ;set extra-time-on-chargers time-to-leave - time-complete-service

   ifelse time-to-leave > time-complete-service [set extra-time-on-chargers time-to-leave - time-complete-service]
          [set extra-time-on-chargers time-to-leave + 1440 - time-complete-service]
        set total-extra-time-on-chargers  (total-extra-time-on-chargers + extra-time-on-chargers)
            set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]
          [

          set total-extra-time-on-chargers  (total-extra-time-on-chargers + charging-time)
          set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]
          ]




         ]
       ]
    ]













     if status = "charging" [

        let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
        let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
        let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger nobody

       ifelse (any? ultra-fast-chargers) [
           set available-charger one-of ultra-fast-chargers
         ]
         [
         set available-charger one-of fast-chargers
         ]

         let real-time ticks
         ;set charging-time max list (ticks - time-entered-service) 0

         ;ifelse time-entered-service < current-time [set charging-time max list (current-time - time-entered-service) 0][ set charging-time current-time - time-entered-service]


        if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]

          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]


      if (current-soc >= soc-threshold-high) [

          if (current-soc <= soc-threshold-high + 2) and charging-time < 45
           [
          set time-complete-service current-time
           ]

          if charging-time >= 45 [

        set time-to-leave current-time
        set color white
        set status "leave"

        ifelse time-complete-service != 0 [
        ;set total-extra-time-on-chargers  (total-extra-time-on-chargers + time-to-leave - time-complete-service)

        ;set extra-time-on-chargers time-to-leave - time-complete-service

        ifelse time-to-leave > time-complete-service [set extra-time-on-chargers time-to-leave - time-complete-service]
          [set extra-time-on-chargers time-to-leave + 1440 - time-complete-service]

        set total-extra-time-on-chargers  (total-extra-time-on-chargers + extra-time-on-chargers)
          set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)]
        [

        set total-extra-time-on-chargers  (total-extra-time-on-chargers + charging-time)
        set total-vehicles-spend-extra-time-on-chargers (total-vehicles-spend-extra-time-on-chargers + 1)

        ]

      ]

       ]




    if (charging-time >= 45) and (current-soc < soc-threshold-high)  [


        if current-soc > soc-threshold-low [

        ifelse available-charger != nobody [
            ifelse member? available-charger ultra-fast-chargers  [
             move-to available-charger
             ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
                      set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)
            ]
            if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
              set status "switch-to-fast-charging" ]
            [

              set color white
              set status "leave"
            ]
          ]
          [
            set color white
            set status "leave"
          ]
        ]



      if current-soc <= soc-threshold-low [

         ifelse available-charger != nobody [
            ifelse member? available-charger ultra-fast-chargers  [
            move-to available-charger

            ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
           set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            set status "switch-to-fast-charging" ]
              [

            set status "charging-until-soc-low"
              ]
             ]
          [

            ;set time-entered-service ticks + t-manoeuvring
            ;set color pink
            set status "charging-until-soc-low"

        ]

      ]
    ]

  ]







  if status = "leave" [

        let nearest-road patch min (list num-ultra-fast-chargers num-fast-chargers num-slow-chargers) 0

        if not any? turtles-on nearest-road [
          move-to nearest-road
          ;set dwell-time charging-time + time-in-queue
          ;set list-charging-time lput charging-time list-charging-time
          ;set list-dwell-time lput dwell-time list-dwell-time
          ;set total-charged-vehicles (total-charged-vehicles + 1)
          set status "driving"
          ]
      ]


 if status = "switch-to-fast-charging" [
         let real-time ticks
         ;set charging-time max list (ticks - time-entered-service) 0
         ;set charging-time max list (ticks - 1440 * (current-day) - time-entered-service) 0
         ;ifelse time-entered-service < current-time [set charging-time max list (current-time - time-entered-service) 0][ set charging-time current-time - time-entered-service]

         ;ifelse time-entered-service < current-time [set charging-time max list (current-time - time-entered-service) 0][ set charging-time current-time - time-entered-service]


        if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]

          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
           set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max ]


        if (current-soc >= soc-threshold-high ) [
          set time-to-leave current-time
          set color white
          set status "leave"

          ;set time-charging-not-on-break time-to-leave - time-entered-service

        ifelse time-to-leave > time-entered-service [set time-charging-not-on-break time-to-leave - time-entered-service]
         [ if time-to-leave != 0 [
           set time-charging-not-on-break time-to-leave + 1440 - time-entered-service
           ]

         ]
          set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)

]

  ]






    if status = "break" [
     let real-time ticks
    ;ifelse (ticks < 1440) [set break-time real-time - time-entered-parking][set break-time real-time - 1440 * current-day  - time-entered-parking]

    ifelse current-time > time-entered-parking [set break-time current-time - time-entered-parking ] [set break-time 1440 - time-entered-parking + current-time ]

    let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
    let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
    let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

     let available-charger nobody
     ifelse (any? ultra-fast-chargers) [
     set available-charger one-of ultra-fast-chargers]
      [
     set available-charger one-of fast-chargers]

    if break-time >= 45 [

      set status "charging-after-break"

    ]

  ]







 if status = "charging-after-break" [

       let real-time ticks
    ;ifelse (ticks < 1440) [set break-time real-time - time-entered-parking][set break-time real-time - 1440 * current-day  - time-entered-parking]
    ifelse current-time > time-entered-parking [set break-time current-time - time-entered-parking] [set break-time 1440 - time-entered-parking + current-time ]


       let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
       let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
       let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

        let available-charger nobody
        ifelse (any? ultra-fast-chargers) [
        set available-charger one-of ultra-fast-chargers]
         [
        set available-charger one-of fast-chargers]

        if not any? turtles-on patch-ahead 1  and [patch-type] of patch-ahead 1 = "queue locations"  [
          fd 1 ]


       let ratio-queue-to-fast length queue / num-ultra-fast-chargers

       ifelse ratio-queue-to-fast <= 1 [

        ifelse (available-charger != nobody) [
        ifelse member? available-charger ultra-fast-chargers [

          if current-soc <= soc-threshold-low [
          ifelse length queue = 0 [
          move-to available-charger
          ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
             set color red
            set status "charging-until-soc-high"
         ]
         [
          move-vehicle-to-queue
          create-virtual-queue1
          set color violet
          set status "waiting-for-fast-chargers"
         ]
        ]

        if current-soc > soc-threshold-low [
          ifelse length queue = 0 [
            move-to available-charger
            ;ifelse (ticks < 1440) [set time-entered-service ticks + t-manoeuvring] [set time-entered-service ticks - 1440 * current-day + t-manoeuvring]
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
              set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
            set color red
            set status "charging-until-soc-high"
         ]
         [

              set color white
              set status "leave"
         ]
        ]


      ]


      [
         ifelse current-soc <= soc-threshold-low [
          move-vehicle-to-queue
          create-virtual-queue1
          set color violet
            set status "waiting-for-fast-chargers" ]
          [
          set color white
            set status "leave"
          ]


      ]
      ]


      [ifelse current-soc <= soc-threshold-low [
          move-vehicle-to-queue
          create-virtual-queue1
          set color violet
        set status "waiting-for-fast-chargers"]
        [
         set color white
          set status "leave"
        ]


    ]
    ]



   [

     ifelse current-soc <= soc-threshold-low [

        ;if length queue < (-1 * min-pxcor ) [
          move-vehicle-to-queue
          create-virtual-queue2
       ;set color green
        ;print(word "queue: " queue)
        ;print(word "length queue " length queue)
        set color green
       set status "queuing-for-charging-or-parking"
      ;]
;        [
;        set color red
;          set status "waiting-for-queuing-space"
;
;        ]
      ]
      [
      set color white
        set status "leave"
      ]

  ]


  ]




 if status = "charging-until-soc-low" [

         let real-time ticks
         ;set charging-time max list (ticks - time-entered-service) 0
         ;ifelse time-entered-service < current-time [set charging-time max list (current-time - time-entered-service) 0][ set charging-time current-time - time-entered-service]

        if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]


          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]

      if current-soc >= soc-threshold-low [

         set color white
         set status "leave"
         set time-complete-service current-time


       ;charging after break
      if break-time >= 45 [

        if arrival-soc != soc-threshold-low [

         set time-charging-not-on-break time-complete-service - time-entered-service

         set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

         set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)
      ]
      ]

      ;just charging until soc-low
     if time-to-break > time-to-break-max and charging-time < 45 [

      if arrival-soc != soc-threshold-low [
         set time-charging-not-on-break time-complete-service - time-entered-service

         set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)]
      ]


      ;after charging for 45mins stillt soc < soc-low
     if charging-time >= 45 [

        if arrival-soc != soc-threshold-low [
         set time-charging-not-on-break time-complete-service - time-entered-service - 45

         set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)

          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1)]
      ]

      ]



  ]



  if status = "charging-until-soc-high" [

         let real-time ticks

       if arrival-day = start-charging-day and current-time >= time-entered-service [
      set charging-time current-time - time-entered-service
     ]

    if arrival-day = start-charging-day and current-time < time-entered-service and current-day = arrival-day [
     set charging-time max list (current-time - time-entered-service) 0
    ]


    if arrival-day = start-charging-day and current-time < time-entered-service and current-day != arrival-day [
     set charging-time 1440 - time-entered-service + current-time
    ]

    if arrival-day != start-charging-day [

      ifelse current-day = arrival-day [
      set charging-time 0
      ]
      [
       set charging-time max list (current-time - time-entered-service) 0
      ]

    ]


          let max-charge-power [ max-power ] of patch-here
          let charge-power nobody

          ifelse (current-soc >= soc-threshold-low and current-soc <= soc-threshold-high ) [
          set charge-power max-charge-power
          ]
          [
          set charge-power max-charge-power * 0.5
          ]

        let energy-delivered charge-power * (mins-per-tick / 60)

        if (charging-time > 0) [
          set current-soc min list (current-soc + energy-delivered / battery-capacity * 100) soc-max
        ]

      if current-soc >= soc-threshold-high [
      set time-complete-service current-time
      set color white
      set status "leave"

      ;charging after break
      if break-time >= 45 [

      if arrival-soc < soc-threshold-high [
      set time-charging-not-on-break time-complete-service - time-entered-service
      set total-time-charging-not-break (total-time-charging-not-break + time-charging-not-on-break)
          set total-vehicles-charging-not-break (total-vehicles-charging-not-break + 1) ]
      ]




      ]





  ]




if status = "waiting-for-fast-chargers" [

     if not any? turtles-on patch-ahead 1  and [patch-type] of patch-ahead 1 = "queue locations"  [
       fd 1 ]

   set time-to-break max list (time-to-break - 1) 0
   let ultra-fast-chargers patches with [ not any? other turtles-here and (patch-type = "ultra-fast charger")]
   let fast-chargers patches with [ not any? other turtles-here and (patch-type = "fast charger")]
   let available-parking one-of patches with [patch-type = "parking spots" and not any? other turtles-here]

   let available-charger nobody

    ifelse (any? ultra-fast-chargers) [
           set available-charger one-of ultra-fast-chargers
         ]
         [
         set available-charger one-of fast-chargers
         ]


   if not empty? queue1 [
       let next-truck first queue1

       let next-charger available-charger

       set time-to-break max list (time-to-break - 1) 0


      ifelse (available-charger != nobody) [

      ifelse member? available-charger ultra-fast-chargers [
          ask next-truck
          [ move-to available-charger
          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
            set start-charging-day (current-day + 1)]
         if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

         if  time-entered-service > 0 and time-entered-queue > 0 [
         ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
            ]
          set total-time-in-queue
              (total-time-in-queue + time-in-queue)

          set queue remove self queue
          set queue1 remove self queue1
          set color red
          set status "fast-charging"
        ]
        ]

      [


         ask next-truck [
            if time-to-break = 0 and (break-time < 45) [
              ifelse current-soc > soc-threshold-low [
              move-to available-charger

                          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
         if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
                ]
              set total-time-in-queue
                  (total-time-in-queue + time-in-queue)

              set queue remove self queue
              set queue1 remove self queue1

          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
                set color blue
                set status "opportunity-charging"]
              [
              move-to available-charger

          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
               set start-charging-day (current-day + 1) ]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]

          if  time-entered-service > 0 and time-entered-queue > 0 [
          ifelse time-entered-service > time-entered-queue [set time-in-queue time-entered-service - t-manoeuvring - time-entered-queue]
              [ set time-in-queue 1440 + time-entered-service - t-manoeuvring - time-entered-queue]
                ]
              set total-time-in-queue
                  (total-time-in-queue + time-in-queue)

              set queue remove self queue
              set queue1 remove self queue1

          set time-entered-service current-time + t-manoeuvring
          if time-entered-service > 1440 [ set time-entered-service current-time + t-manoeuvring - 1440
                set start-charging-day (current-day + 1)]
          if time-entered-service < 1440 and current-day != arrival-day [set start-charging-day (arrival-day + 1) ]
                set color blue
              set status "charging"

              ]
          ]
          ]
    ]

    ]




    [
         ask next-truck [
          if time-to-break = 0 and (break-time < 45)  [
            move-to available-parking
           set time-entered-parking current-time
           ifelse time-entered-parking >= time-entered-queue [set time-in-queue time-entered-parking - time-entered-queue]
            [set time-in-queue 1440 + time-entered-parking - time-entered-queue]
           set total-time-in-queue
              (total-time-in-queue + time-in-queue)

           set queue remove self queue
           set queue1 remove self queue1
           set time-entered-parking current-time
           ;set color yellow
           set status "break"
            ;print (word "time-to-break " time-to-break)] ]


    ]

  ]

  ]
    ]
  ]


if status = "queuing-for-charging-or-parking"[

    if not any? turtles-on patch-ahead 1  and [patch-type] of patch-ahead 1 = "queue locations"  [
          fd 1 ]
    begin-service
  ]



end


to-report day
  report current-day
end

to-report time
  report current-time
end


to-report clock
  let hours floor (current-time / 60)
  let minutes remainder  current-time  60
  if hours >= 24 [
    set hours hours - 24 ]
  report (word hours ":" minutes)
end



to-report amount-of-time-vehicles-queuing

  report total-time-in-queue
end


to-report number-of-trucks-queuing

  report total-trucks-in-queue

end


to-report average-time-in-queue

  ifelse (total-trucks-in-queue > 0) [

   report precision ( total-time-in-queue / total-trucks-in-queue) 2
  ]
  [report 0]

end


to-report amount-of-time-charging-not-break

  report total-time-charging-not-break

end

to-report total-trucks-charging-not-break

  report total-vehicles-charging-not-break

end


to-report average-time-charging-not-break

  ifelse (total-vehicles-charging-not-break > 0) [

   report precision (total-time-charging-not-break / total-vehicles-charging-not-break) 2
  ]
  [report 0]

end

to-report amount-of-time-extra-charging

  report total-extra-time-on-chargers

end


to-report total-vehicles-extra-charging

  report total-vehicles-spend-extra-time-on-chargers
end




to-report average-extra-time-on-chargers

  ifelse (total-vehicles-spend-extra-time-on-chargers > 0) [

   report precision (total-extra-time-on-chargers / total-vehicles-spend-extra-time-on-chargers) 2
  ]
  [report 0]

end


to-report battery-capacity-ratio

  ;let ratio count turtles with [battery-capacity = 250] / count turtles with [battery-capacity = 550]

  let ratio small-vehicles-count / large-vehicles-count
  report precision ratio 1

end
@#$#@#$#@
GRAPHICS-WINDOW
19
294
838
426
-1
-1
24.6
1
10
1
1
1
0
0
0
1
-16
16
-2
2
1
1
1
ticks
30.0

BUTTON
32
22
98
55
NIL
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

SLIDER
287
184
469
217
num-fast-chargers
num-fast-chargers
2
max-pxcor - 1
4.0
1
1
NIL
HORIZONTAL

SLIDER
285
234
468
267
num-slow-chargers
num-slow-chargers
1
max-pxcor - 1
4.0
1
1
NIL
HORIZONTAL

BUTTON
117
22
180
55
NIL
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

SLIDER
286
91
468
124
num-parking-spots
num-parking-spots
0
30
20.0
1
1
NIL
HORIZONTAL

SLIDER
34
138
206
171
soc-threshold-high
soc-threshold-high
50
100
80.0
10
1
NIL
HORIZONTAL

PLOT
43
447
260
621
Arrival SOC distribution
soc
num trucks
0.0
100.0
0.0
8.0
true
false
"" ""
PENS
"default" 0.5 1 -8630108 true "" "set-plot-y-range 0 8\nhistogram [arrival-soc] of trucks \n\n\n\n"

BUTTON
197
23
260
56
step
go
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

PLOT
515
128
726
281
Queuing trucks
ticks
num trucks
0.0
5000.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "ifelse (queue = 0) [plot 0\n]\n[plot length queue]\n\n"

SLIDER
285
137
471
170
num-ultra-fast-chargers
num-ultra-fast-chargers
2
max-pxcor - 1
2.0
1
1
NIL
HORIZONTAL

SLIDER
32
186
208
219
ratio-large-vehicle
ratio-large-vehicle
0
1
0.8
0.1
1
NIL
HORIZONTAL

SLIDER
33
94
205
127
soc-threshold-low
soc-threshold-low
0
50
20.0
1
1
NIL
HORIZONTAL

MONITOR
738
235
829
280
current time
time
17
1
11

MONITOR
739
182
827
227
Clock
clock
25
1
11

MONITOR
510
449
759
494
Amount of time vehicles queuing
amount-of-time-vehicles-queuing
17
1
11

PLOT
275
447
495
621
Arrival time-to-break distribution
NIL
NIL
0.0
240.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "set-plot-y-range 0 10\nhistogram [time-to-break] of trucks "

MONITOR
807
450
1005
495
Total trucks queuing
number-of-trucks-queuing
17
1
11

MONITOR
808
513
1009
558
Total trucks charging not break
total-trucks-charging-not-break
17
1
11

MONITOR
512
572
764
617
Total extra time on chargers
amount-of-time-extra-charging
17
1
11

MONITOR
513
510
762
555
Amount of time charging not on break
amount-of-time-charging-not-break
17
1
11

MONITOR
808
572
1013
617
Total vehicles extra charging
total-vehicles-extra-charging
17
1
11

TEXTBOX
603
404
753
422
1MW charger
13
15.0
1

TEXTBOX
604
380
754
398
350 kW chager
13
15.0
1

TEXTBOX
666
329
816
347
150 kW charger
13
15.0
1

TEXTBOX
253
302
403
320
Parking
13
65.0
1

TEXTBOX
41
304
191
322
Queue location
13
88.0
1

TEXTBOX
850
345
1000
375
Red: vehicles using 1MW chargers\n
12
15.0
1

TEXTBOX
850
262
1000
322
Purple (break): when time-to-break equals 0, vehicles go for break if no charger available
12
115.0
1

TEXTBOX
1183
341
1333
371
Green: vehicles return to the queue after parking 
12
65.0
1

TEXTBOX
852
390
1002
420
Blue: vehicels using 350 kW chargers for charging
12
105.0
1

TEXTBOX
1014
256
1164
316
Pink: vehicles using 350 kW charging to SoC-threshold-low, then change to another case
12
134.0
1

TEXTBOX
1013
386
1163
416
Yellow: vehicles switch to charging status from pink
12
44.0
1

MONITOR
1045
449
1220
494
Avg. queuing time
average-time-in-queue
17
1
11

MONITOR
1046
513
1224
558
Avg. time charging not break
average-time-charging-not-break
17
1
11

MONITOR
1048
575
1229
620
Avg. extra time on chargers
average-extra-time-on-chargers
17
1
11

TEXTBOX
1012
338
1162
368
Purple (queuing): vehicles wait for 1MW chargers
12
114.0
1

TEXTBOX
1180
256
1330
331
Purple (charging): when time-to-break equals 0, vehicles go for charging if a 350kW charger is free 
12
114.0
1

INPUTBOX
286
11
515
71
arrivals-file
default_arrivals_day0.csv
1
0
String

MONITOR
739
130
828
175
current day
day
17
1
11

SLIDER
513
83
699
116
num-days
num-days
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
33
232
212
265
time-manoeuvring
time-manoeuvring
0
15
8.0
1
1
NIL
HORIZONTAL

INPUTBOX
526
10
755
70
random-number-seed
0
1
0
String

TEXTBOX
764
12
938
72
0 = choose a random seed To set a manual seed, choose any positive number
12
0.0
1

SWITCH
723
82
833
115
logging?
logging?
1
1
-1000

TEXTBOX
852
82
1055
113
Please 'setup' model again after turning logging on or off
12
0.0
1

@#$#@#$#@
## WHAT IS IT?

This NetLogo model simulates an electric vehicle charging station, modeling the behavior of electric trucks as they arrive, charge their batteries, and take breaks as needed.

## HOW IT WORKS

In this model, trucks are created with some initial properties, such as status, state of charge (SOC), battery capacity, initial position, color, etc. Patches are created to represent various functions, such as roads, parking spots, and different types of chargers.

Truck has variuous stutus in this model, driving, charging, resting and drive on. 

In the ""driving" stutus, if a truck encounters a charging station and needs to be charged, it attempts to find a free charger. If found, it moves to the charger and starts charging. If no free charger is available, the truck joins the queue and waits for charging. If there is no space in the queue, the vehicle passes the station and continues driving.

If a truck reaches a charging station but doesn't need to charge (SOC > threshold) and has been driving for more than the maximum journey time, it attempts to find an available parking spot. If found, it moves to the parking spot and enters the "rest" status. If no parking spot is available, it drives on.

If a truck is in the "charging" status, it calculates the energy delivered during the current tick and updates its SOC and color based on the charging progress. The truck checks if it has reached an SOC of 80% and moves to the nearest road if it's not busy, indicating that it's ready to resume driving.

If a truck is in the "rest" status, it accumulates rest time until a break duration of 45 minutes is reached. Afterward, the truck moves to the nearest road and resumes driving.


## HOW TO USE IT

"Setup": Click this button to initialize the simulation. It sets up the environment, global parameters.

 "Go": Click this button to start or continue the simulation. The simulation will run according to the specified parameters until it reaches the maximum run time.


"num-parking-spots": Set the number of available parking spots for trucks to take breaks.

"num-ultra-fast-chargers", "num-fast-chargers" and "num-slow-chargers": Set the number of ultra-fast, fast and slow chargers available in the charging station.

"soc-threshold": Set the state of charge (SOC) threshold at which a truck decides whether to charge or take a break.

Several monitors provide real-time information about key metrics during the simulation:

 "current time":  Displays the current simulation time.

 "Arrival Rate": Shows the current vehicle arrival rate based on the time of day.

 "total served Vehicles": Displays the number of vehicles successfully charged.

 "total unserved vehicles": Shows the number of vehicles that couldn't charge due to unavailability.

The Interface tab also includes several plots that display key simulation metrics over time, including the proportion of unserverd vehicles, total number of served vehicles, total number of unserved vehicles, soc distribution, journey time distrition, queuing trucks, and charger occupancy etc.


## THINGS TO NOTICE

(suggested things for the user to notice while running the model)


## THINGS TO TRY

Run the simulation several times to get a sense of the effects of different numbers of chargers and arrival rates on the performance of the charging station


## EXTENDING THE MODEL

This model could introduce more complex charging behavioral rules for the trucks, such as drivers staying for a particular dwell time and then leaving

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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="default_experiment" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>average-time-in-queue</metric>
    <metric>average-time-charging-not-break</metric>
    <metric>average-extra-time-on-chargers</metric>
    <enumeratedValueSet variable="num-parking-spots">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ratio-large-vehicle">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-num-hours">
      <value value="24"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-slow-chargers">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="soc-threshold-low">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-fast-chargers">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-ultra-fast-chargers">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="soc-threshold-high">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="arrivals-file">
      <value value="&quot;defulat_arrivals.csv&quot;"/>
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
