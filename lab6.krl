ruleset manage_sensors {
  meta {
    shares __testing, sensors, get_temps
    
    use module io.picolabs.wrangler alias Wrangler
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "sensors", "args": [] },
      { "name": "get_temps", "args": [] }
      ] , "events":
      [ { "domain": "sensor", "type": "new_sensor", "attrs": ["name"]}
      , { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "name" ] }
      ]
    }
    
    default_threshold = 69
    default_number = "+19492145651"
    
    sensors = function() {
      ent:sensors.defaultsTo({});
    };
    
    get_temps = function() {
      
      ent:sensors.map(function(v,k) { 
        Wrangler:skyQuery(v["eci"],"temperature_store","temperatures",null);
      })
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
          "rids" : ["temperature_store", "wovyn_base", "sensor_profile", "twilio.keys", "twilio.module", "twilio.send"],
          "name" : new_name,
        }
    }
  }
  
  
  rule store_sensor {
    select when wrangler child_initialized
    
    pre {
      name = event:attr("name")
      eci = event:attr("eci")
      id = event:attr("id")
      args = {"id":id, "eci":eci }
    }
    
    noop()
    
    fired {
      ent:sensors := ent:sensors.defaultsTo({}).put([name], args)
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
    }
    
    
  rule delete_sensor {
    select when sensor unneeded_sensor
      pre {
        name = event:attr("name")
        exists = ent:sensors.keys() >< name
      }
      
      if exists then
        send_directive("Deleting " + name + " sensor")
      
      fired {
        ent:sensors := ent:sensors.defaultsTo({}).delete([name])
        raise wrangler event "child_deletion"
          attributes {
            "name": name
          }
      }
      
  }
  
}
