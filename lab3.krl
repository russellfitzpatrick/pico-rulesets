ruleset wovyn_base {
  meta {
    shares __testing
    
    use module twilio.keys
    use module twilio.module alias twilio
    use module sensor_profile alias sensor
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "wovyn", "type": "heartbeat", "attrs": ["genericThing"] }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    //temperature_threshold = 69
    
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat where event:attr("genericThing")
    
    
    pre {
      never_used = event:attr().klog("attrs")
      //temperature = event:attr("genericThing").decode() {"data"}.decode() {"temperature"}.decode().head() {"temperatureF"}.decode()
      temperature = event:attr("genericThing")
    }
        send_directive("Received Heartbeat with temperature of " + temperature + " at " + time:now())
        fired{
        raise wovyn event "new_temperature_reading"
        attributes { "temperature" : temperature, "timestamp" : time:now() }
        }
  }
  
  
  rule find_high_temps {
  select when wovyn new_temperature_reading
    pre {
      temperature = event:attr("temperature")
      time = event:attr("timestamp")
      directive = (event:attr("temperature") > sensor:get_threshold()) => "There has been a temperature violation" | 
      "There has not been a temperature violation"
    }
    send_directive(directive)
                fired{
        raise wovyn event "threshold_violation" 
        attributes { "temperature" : temperature, "timestamp" : time } 
        if event:attr("temperature") > sensor:get_threshold()
        } 
  }
  
  
  rule threshold_notification {
    select when wovyn threshold_violation
    
      send_directive("Sent Text")
      
      fired{
//        raise test event "new_message"
//        attributes { "to": sensor:get_number(), "from": "+12564483037", "message":"temp threshold"}
      }
  }
  
}
