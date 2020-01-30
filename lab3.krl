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
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat where event:attr("genericThing")
    
    
    pre {
      genericThing = event:attr("genericThing")
      temperature = genericThing.decode() {"data"}
    }
        //send_directive(temperature)
        fired{
        raise wovyn event "new_temperature_reading"
        }
  }
  
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
        send_directive("This is also working")
                fired{
        raise wovyn event "threshold_violation"
        }
  }
  
  
  rule threshold_notification {
    select when wovyn threshold_violation
    
      send_directive("Sent Text")
      
      fired{
        raise test event "new_message"
        attributes { "to": "+19492145651", "from": "+12564483037", "message":"temp threshold"}
      }
  }
  
}

