ruleset manage_sensors {
  meta {
    shares __testing, sensors, get_temps
    
    use module io.picolabs.wrangler alias Wrangler
    use module io.picolabs.subscription alias Subscriptions
    use module twilio.keys
    use module twilio.module alias twilio
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "sensors", "args": [] },
      { "name": "get_temps", "args": [] }
      ] , "events":
      [ { "domain": "sensor", "type": "new_sensor", "attrs": ["name"]}
      , { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "name" ] },
      { "domain": "sensor", "type": "subscribe", "attrs": [ "name", "eci", "host", "port" ] }
      ]
    }
    
    default_threshold = 69
    default_number = "+19492145651"
    
    sensors = function() {
      ent:sensors.defaultsTo({});
    };
    
    get_temps = function() {
      Subscriptions:established("Tx_role","sensor").map(function(x) {
        Wrangler:skyQuery(x["Tx"],"temperature_store","temperatures",null) })
    }
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
      name = Wrangler:skyQuery(eci,"sensor_profile","get_name",null)
      
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
