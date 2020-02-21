ruleset sensor_profile {
  meta {
    shares __testing, get_threshold, get_number
    
    provides get_threshold, get_number
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "sensor", "type": "get_profile" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
  get_threshold = function() {
   ent:threshold.defaultsTo(69);
 };
 
  get_location = function() {
    ent:location.defaultsTo("Provo");
  };
  
    get_name = function() {
    ent:name.defaultsTo("Best User");
  };
  
    get_number = function() {
    ent:number.defaultsTo("+19492145651");
  };
}

  
  rule get_profile {
    select when sensor get_profile
      
      send_directive("Profile", {"threshold": get_threshold(),
        "location": get_location(),
        "name": get_name(),
        "number": get_number()
      })
    
  }
  
  
  rule update_profile {
    select when sensor profile_updated
    
    pre {
      location = event:attr("location")
      threshold = event:attr("threshold")
      number = event:attr("number")
      name = event:attr("name")
    }
    
    fired {
      ent:location := location => location | ent:location
      ent:threshold := threshold => threshold | ent:threshold
      ent:number := number => number | ent:number
      ent:name := name => name | ent:name
    }
  }
  
}
