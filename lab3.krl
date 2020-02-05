ruleset wovyn_base {
  meta {
    shares __testing
    
    use module twilio.keys
    use module twilio.module alias twilio
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
    
    temperature_threshold = 80
    
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat where event:attr("genericThing")
    
    
    pre {
      never_used = event:attr().klog("attrs")
      test = event:attr("genericThing").decode() {"data"}.decode() {"temperature"}.decode().head() {"temperatureF"}.decode()
      temperature = 70
    }
        send_directive("Received Heartbeat with temperature of " + temperature + " at " + time:now())
        fired{
        raise wovyn event "new_temperature_reading"
        attributes { "temperature" : temperature, "timestamp" : time:now() }
        }
  }
  
  
//  rule find_high_temps {
//  select when wovyn new_temperature_reading
//    pre {
//      directive = (event:attr("temperature") > temperature_threshold) => "There has been a temperature violation" | 
//      "There has not been a temperature violation"
//    }
//    send_directive(directive)
//                fired{
//        raise wovyn event "threshold_violation" if event:attr("temperature") > temperature_threshold
//        } 
//  }
  
  
  rule threshold_notification {
    select when wovyn threshold_violation
    
      send_directive("Sent Text")
      
      fired{
        raise test event "new_message"
        attributes { "to": "+19492145651", "from": "+12564483037", "message":"temp threshold"}
      }
  }
  
}


