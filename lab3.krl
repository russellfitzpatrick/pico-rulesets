ruleset wovyn_base {
  meta {
    shares __testing
    
    use module twilio.keys
    use module twilio.module alias twilio
    use module sensor_profile alias sensor
    use module temperature_store alias store
    use module io.picolabs.subscription alias Subscriptions
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
    
      pre{
        eci = Subscriptions:established("Tx_role","sensor_manager").map(function(x) {x["Tx"]}).head()
        host = Subscriptions:established("Tx_role","sensor_manager").map(function(x) {x["Tx_host"]}).head()
        temp = event:attr("temperature")
      }
    
      event:send({
        "eci": eci, "eid": null,
        "domain": "sensor", "type": "threshold_violation",
        "attrs": {"name":sensor:get_name(),
                  "number":sensor:get_number(),
                  "temp":temp
        }
      }, host=host )
  }
  
  rule create_report {
    select when sensor generate_report
    
    pre {
      Tx = event:attr("originator")
      host = event:attr("orig_host")
      id = event:attr("id")
      Rx = event:attr("Tx")
      
      temps = store:temperatures()
    }
    
    event:send({
        "eci": Tx, "eid": null,
        "domain": "manager", "type": "report_generated",
        "attrs": {"temps":temps,
                  "Tx":Rx,
                  "id":id
        }
      }, host=host )
    
    //send_directive("Generating report...")
  }
}
