# eHGV-charging-ABM

 Step 1: Extract and preprocess traffic data from the MIDAS dataset for the M20 motorway.
 
 Step 2: Analyze daily traffic patterns for weekdays and weekends.

 Step 3: Calculate the average hourly arrivals for the following key cases at the service station, distinguishing between weekdays and weekends.
 
 |                   |low charge|Medium Charge| High charge|
 |------------------ |----------|--------------|------------|
 |**Rest break imminent**|1         |4            |7           |
 |**Rest break soon**    |2         |5            |8           |
 |**Rest break distant** |3         |6            |9           |
 

 Step 4: Run simulation experiments in PyNetLogo based on the arrival patterns derived in Step 3.
