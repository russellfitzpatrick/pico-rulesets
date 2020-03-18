ruleset manage_sensors {
  meta {
    shares __testing, sensors, get_temps, get_temps_report
    
    use module io.picolabs.wrangler alias Wrangler
    use module io.picolabs.subscription alias Subscriptions
    use module twilio.keys
    use module twilio.module alias twilio
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "sensors", "args": [] },
      { "name": "get_temps", "args": [] },
      { "name": "get_temps_report", "args": [] }
      ] , "events":
      [ { "domain": "sensor", "type": "new_sensor", "attrs": ["name"]}
      , { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "name" ] },
      { "domain": "sensor", "type": "subscribe", "attrs": [ "name", "eci", "host", "port" ] },
      {"domain": "manager", "type": "generate_report" }
      ]
    }
    
    default_threshold = 69
    default_number = "+19492145651"
    report_number = 0
    
    sensors = function() {
      ent:sensors.defaultsTo({});
    };
    
    get_temps = function() {
      Subscriptions:established("Tx_role","sensor").map(function(x) {
        Wrangler:skyQuery(x["Tx"],"temperature_store","temperatures",null, x["Tx_host"]) })
    }
    
    get_temps_report = function() {
      min = ent:temperature_reports.length() - 5
      min = (min < 0) => 0 | min
      ent:temperature_reports.filter(function(v,k)
      {
        v["report_number"] >= min
      })
    }
  }
  
  rule generate_new_id {
    select when manager generate_report
    
    pre {
      id = random:uuid()
    }
    
    fired {
      ent:temperature_reports := ent:temperature_reports.defaultsTo({})
//      ent:temperature_reports{id} := ent:temperature_reports.put(id)
      ent:report_number := ent:report_number.defaultsTo(0)
      ent:temperature_reports{id} := {"temperature_sensors":Subscriptions:established("Tx_role","sensor").length(),
                                      "responding": 0, "report_number":ent:report_number, "temperatures": {} }
                                      
//      ent:temperature_reports := ent:temperature_reports.filter( function(v,k) { v["report_number"]  }) 
      ent:report_number := ent:report_number + 1
      raise manager event "request_reports"
      attributes {
        "id": id,
      }
    }
  }
  
  rule create_temp_report {
    select when manager request_reports
    
      foreach Subscriptions:established("Tx_role","sensor") setting(x)
      
      pre {
        id = event:attr("id")
      }
          event:send({
        "eci": x["Tx"], "eid": null,
        "domain": "sensor", "type": "generate_report",
        "attrs": {"originator":x["Rx"], "orig_host":meta:host,
          "Tx":x["Tx"], "id":id
        }
      }, host=x["Tx_host"])
        
  }
  
  
  rule new_temp_report {
    select when manager report_generated
    
    pre {
      
      temps = event:attr("temps")
      Tx = event:attr("Tx")
      id = event:attr("id")
    }
    
    fired {
      ent:temperature_reports{[id, "responding"]} := ent:temperature_reports{[id, "responding"]} + 1
      ent:temperature_reports{[id, "temperatures", Tx]} := temps
      raise manager event "check_status"
      attributes {
        "id": id
      }
    }
  }
  
  rule check_report_status {
    select when manager check_status
    pre {
      id = event:attr("id")
    }
    
    if ent:temperature_reports{[id, "responding"]} == Subscriptions:established("Tx_role","sensor").length()
      then send_directive("Report " + id + " is ready")
  }
  
  rule create_sensor {
    select when sensor new_sensor
    
    pre {
      new_name = event:attr("name")
      name_exists = ent:sensors.defaultsTo({}) >< new_name
    }
    if name_exists then
      send_directive("Sensor with that name already exists")
    notfired {
      //ent:sensors := ent:sensors.defaultsTo({}).put([new_name], new_eci)
      raise wrangler event "child_creation"
        attributes {
          "rids" : ["temperature_store", "wovyn_base", "sensor_profile"],
          "name" : new_name
        }
    }
  }
  
  
  rule store_sensor {
    select when wrangler child_initialized
    
    pre {
      name = event:attr("name")
      eci = event:attr("eci")
      id = event:attr("id")
    }
    
    fired {
//      ent:sensors := ent:sensors.defaultsTo([]).append(name)
      raise sensor event "post"
      attributes {
        "name": name,
        "eci": eci
      }
    }
  }
  
  rule send_post {
    select when sensor post
    
    pre {
      name = event:attr("name")
      eci = event:attr("eci")
      args = {"name":name, "number":default_number, "threshold":default_threshold }
    }
      event:send({
        "eci": eci, "eid": null,
        "domain": "sensor", "type": "profile_updated",
        "attrs": args
      })
      
    fired {
      raise sensor event "subscribe"
      attributes {
        "name":name,
        "eci": eci,
        "host": "localhost",
        "port": 8080
      }
    }
    }
   
   
  rule create_subscription {
    select when sensor subscribe
      pre {
      name = event:attr("name")
      eci = event:attr("eci")
      host = event:attr("host")
      port = event:attr("port")
    }
    
    fired {
      raise wrangler event "subscription" attributes
       { "name" : name,
         "Rx_role": "sensor_manager",
         "Tx_role": "sensor",
         "channel_type": "subscription",
         "wellKnown_Tx" : eci,
         "Tx_host": "http://" + host + ":" + port
       }
    }
  } 
    
  rule delete_sensor {
    select when sensor unneeded_sensor
      pre {
        name = event:attr("name")
        exists = ent:sensors.keys() >< name
        tx = ent:sensors.get([name])
      }
      
      if exists then
        send_directive("Deleting " + name + " sensor")
      
      fired {
//        ent:sensors := ent:sensors.defaultsTo({}).delete(name)
        raise wrangler event "subscription_cancellation"
          attributes {
            "Tx": tx
          }
      }
      
  }
  
  rule deleting_sensor {
    select when wrangler subscription_removed
    
    pre {
      bus = event:attr("bus")
      tx = bus["Tx"]
      sensor = ent:sensors.filter(function(v,k) {v == tx})
      name = sensor.keys()[0]
    }
    
    fired {
      ent:sensors := ent:sensors.defaultsTo({}).delete(name)
      raise wrangler event "child_deletion"
          attributes {
            "name": name
          }
    }
  }
  
  rule add_sensor {
    select when wrangler subscription_added
    
    pre{
      eci = event:attr("Tx")
      bus = event:attr("bus")
      uri = bus["Tx_host"]
      name = Wrangler:skyQuery(eci,"sensor_profile","get_name",null,uri)
      
    }
    
    fired {
      ent:sensors := ent:sensors.defaultsTo({}).put([name], eci)
    }
  }
  
    rule threshold_notification {
    select when sensor threshold_violation
    
      pre {
        name = event:attr("name")
        temp = event:attr("temp")
        number = event:attr("number")
      }
    
      send_directive("Sent Text to " + number + " because of " + name)
      
      fired{
        raise test event "new_message"
        attributes { "to": number, "from": "+12564483037", "message": name + " has had a threshold violation of " + temp}
      }
  }
  
}
