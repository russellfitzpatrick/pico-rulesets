ruleset temperature_store {
  meta {
    shares __testing//, temperatures, threshold_violations, inrange_temperatures
    
    provides temperatures, threshold_violations, inrange_temperatures
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "temperatures", "args": [] }
      , { "name": "threshold_violations", "args": [] }
      , { "name": "inrange_temperatures", "args": [] }
      ] , "events":
      [ { "domain": "wovyn", "type": "heartbeat", "attrs": ["genericThing"] }
      , { "domain": "sensor", "type": "reading_reset", "attrs": [] }
      ]
    }
    
    temperatures = function() {
      ent:new_temps.defaultsTo([])
    }
    
    threshold_violations = function() {
      ent:violations.defaultsTo([])
    }
    
    inrange_temperatures = function() {
      ent:new_temps.filter(function(x){ not (ent:violations >< x)})
    }
  }
  
  rule collect_temperatures {
  select when wovyn new_temperature_reading
    pre {
      temperature = event:attr("temperature")
      time = event:attr("timestamp")
    }
    send_directive("New Temp")
    fired{
      ent:new_temps :=  ent:new_temps.defaultsTo([]).append({"temperature" : temperature, "timestamp" : time})
    } 
  }
  
    rule collect_threshold_notifications {
    select when wovyn threshold_violation
      pre {
        temperature = event:attr("temperature")
        time = event:attr("timestamp")
      }
      send_directive("Violation")
      
      fired{
        ent:violations :=  ent:violations.defaultsTo([]).append({"temperature" : temperature, "timestamp" : time})
      }
  }
  
  rule clear_temperatures {
    select when sensor reading_reset
    
    fired{
      clear ent:violations
      clear ent:new_temps
    }
  }
}
