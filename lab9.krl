ruleset gossip {
  meta {
    shares __testing, get_seen, get_tracker, get_temperature_readings
    
    provides get_peer, prepare_message, update_state
    
    use module temperature_store alias store
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      , { "name": "get_seen" }
      , { "name": "get_tracker" }
      , { "name": "get_temperature_readings" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "gossip", "type": "heartbeat" }
      , { "domain": "gossip", "type": "start_timer" }
      , { "domain": "gossip", "type": "get_temps" }
      , { "domain": "gossip", "type": "process" }
      , { "domain": "gossip", "type": "subs" }
      , { "domain": "gossip", "type": "change_seconds", "attrs": ["n"] }
      ]
    }
    
    get_seen = function() {
      ent:seen.defaultsTo({})
    };
    
    get_tracker = function() {
      ent:tracker.defaultsTo({})
    };
    
    get_temperature_readings = function() {
      ent:temperature_readings.defaultsTo({})
    };
    
    temp = {}
    rumors = {}
    peer = ""
    biggest_difference = 0
  }


  rule get_subscriptions {
    select when gossip subs
//    foreach ent:tracker setting(v,k)
      foreach (Subscriptions:established("Tx_role","node") && Subscriptions:established("Rx_role","node"))  setting(k)
      
      send_directive(k["Tx"])
      
      fired {
        log debug k
      }
      
  }    
      
  
  rule on_installation{
  select when wrangler ruleset_added where meta:rid == "gossip" // if this ruleset has just been installed
  pre {
  }
  noop()
  fired{
    ent:temperature_readings := ent:temperature_readings.defaultsTo({})
    ent:tracker := ent:tracker.defaultsTo({})
    ent:seen := ent:seen.defaultsTo({})
    ent:seen_value := ent:seen_value.defaultsTo(0)
    ent:new_temps := ent:new_temps.defaultsTo([])
    ent:processing := ent:processing.defaultsTo("on")
  }
}


  rule get_new_temps {
    select when gossip get_temps
    foreach store:temperatures().difference(ent:new_temps) setting(x)
      
      pre {
        temperature = x{"temperature"}.klog("Temp")
        timestamp = x{"timestamp"}.klog("Time")
        messageId = meta:picoId + ":" + ent:seen_value
      }
      
      send_directive("Gossip temp")
    fired{
      log debug x
      ent:new_temps := ent:new_temps.append(x)
      ent:temperature_readings := ent:temperature_readings.defaultsTo({})
      ent:tracker := ent:tracker.defaultsTo({})
      ent:seen := ent:seen.defaultsTo({})
      ent:seen_value := ent:seen_value.defaultsTo(0)
      ent:temperature_readings{[meta:picoId, messageId]} :=  {"SensorId": meta:picoId, "MessageId": messageId, "temperature" : temperature, "timestamp" : timestamp}
      ent:seen{meta:picoId} := ent:seen_value.as("Number")
      ent:seen_value := ent:seen_value.as("Number") + 1
    }
  }



rule update_processing {
  select when gossip process
  
  fired {
    ent:processing := (ent:processing.defaultsTo("on") == "on") => "off" | "on"
  }
}

rule update_n {
  select when gossip change_seconds
  
  pre {
    new_n = event:attr("n")
  }
  
  fired {
    ent:n := new_n
  }
}  

rule timer_start {
  select when gossip start_timer
  
  fired {
    schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:n.defaultsTo(5)})
  }
}
  
  
  rule get_peer_ids {
  select when wrangler subscription_added
  foreach (Subscriptions:established("Tx_role","node") && Subscriptions:established("Rx_role","node"))  setting(x)
  noop()
  fired {
    ent:tracker{x{"Tx"}} := ent:tracker{x{"Tx"}}.defaultsTo({})
  }
}

rule restock_tracker{
  select when gossip restock where ent:processing == "on"
    foreach (Subscriptions:established("Tx_role","node") && Subscriptions:established("Rx_role","node"))  setting(x)
  noop()
  fired {
    ent:tracker{x{"Tx"}} := ent:tracker{x{"Tx"}}.defaultsTo({})
    raise gossip event "updatetracker" on final
  }
}

rule update_tracker {
  select when gossip updatetracker
      foreach ent:tracker setting(v,k)
      foreach ent:seen setting(seen_value, seen_id)
      
      
      fired {
        ent:tracker{[k, seen_id]} := (ent:tracker{[k, seen_id]}.klog("tracker initial") == null) => -1 | ent:tracker{[k, seen_id]}.as("Number")
        log debug ent:tracker
      }
      finally {
        raise gossip event "action" on final
      }
}
  
  rule heartbeat {
    select when gossip heartbeat where ent:processing == "on"
    
    fired {
      raise gossip event "restock"
      raise gossip event "get_temps"
    }
    finally {
      //schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:n.defaultsTo(5)})
    }
  }
  
  rule action {
    select when gossip action
        pre {
    n = random:integer(lower = 0, upper = 1)
//n = 1
    }
      
    if n == 1 then noop()  
    
    
    fired {
      raise gossip event "peer"
    }
    else {
      raise gossip event "update_seen"
    }
  }
  
  
  rule get_peers {
    select when gossip peer
//    foreach ent:tracker setting(v,k)
      foreach (Subscriptions:established("Tx_role","node") && Subscriptions:established("Rx_role","node"))  setting(k)
      foreach ent:seen setting(seen_value, seen_id)
      
      pre {
        Tx = k["Tx"]
      }
    
    if Subscriptions:established("Tx", Tx) then noop()
    
    fired {
      log debug seen_id
      log debug seen_value
      temp = temp{Tx} => temp.put([Tx], temp{Tx}) | temp.put([Tx], {})
      temp = temp.put([Tx], ent:tracker{Tx}.filter(function(v,k){
        v.as("Number").klog("Value") < seen_value.as("Number") && k.klog("key") == seen_id})).klog("temp")
      //log debug ent:tracker{[ent:tracker.keys().head(), seen_id]}.defaultsTo(-1)
    }
    finally {
      temp = temp.filter(function(v,k) {v.length() > 0}).klog("temp final") on final
      raise gossip event "filter"  attributes { "peers":temp } on final
      temp = {} on final
    }
  }
  
  rule choose_peer {
    select when gossip filter where event:attr("peers").length() > 0
    foreach event:attr("peers") setting(v,k)
    
    if v.length() > biggest_difference && Subscriptions:established("Tx", peer)then
      noop()
      
    fired {
      biggest_difference = v.length()
      peer = k
    }
    finally {
      raise gossip event "prepare_message" attributes { "peer":event:attr("peers"){peer}, "Tx":peer } on final
      peer = "" on final
      biggest_difference = 0 on final
    }
    
  }
  
  rule message_prep {
    select when gossip prepare_message where event:attr("peer").length() > 0
    pre{
      peer = event:attr("peer").klog("Peer")
      Tx = event:attr("Tx").klog("Tx")
      id = peer.keys().head().klog("id")
      value = peer{id}.as("Number").klog("value of message")
      messageId = (id + ":" + (value + 1)).klog("messageId")
      
      rumor_to_send = ent:temperature_readings{[id, messageId]}.klog("rumor_to_send")
      temperature = rumor_to_send{"temperature"}
      SensorId = rumor_to_send{"SensorId"}
      MessageId = rumor_to_send{"MessageId"}
      timestamp = rumor_to_send{"timestamp"}
      
      x = Subscriptions:established("Tx", Tx).head().klog("subscription")
    }


      fired {
        ent:tracker{[Tx, id]} := (value + 1)
        raise gossip event "send_rumor" attributes {
          "SensorId": SensorId, "MessageId": MessageId, "temperature" : temperature, "timestamp" : timestamp, "subscription":x
        }
      }
  }
  
  rule send_message {
    select when gossip send_rumor
    
    pre {
      temperature = event:attr("temperature")
      SensorId = event:attr("SensorId")
      MessageId = event:attr("MessageId")
      timestamp = event:attr("timestamp")
      x = event:attr("subscription")
    }
    
    event:send({
        "eci": x["Tx"], "eid": null,
        "domain": "gossip", "type": "rumor",
        "attrs": {"SensorId":SensorId,
                  "MessageId":MessageId,
                  "temperature":temperature,
                  "timestamp":timestamp,
                  "Tx":x["Rx"]
        }
      }, host=x["Tx_host"].defaultsTo("http://localhost:8080"))
  }
  
  rule get_rumor {
    select when gossip rumor where ent:processing == "on"
    pre {
      timestamp = event:attr("timestamp")
      temperature = event:attr("temperature")
      SensorId = event:attr("SensorId")
      MessageId = event:attr("MessageId")
      value = MessageId.split(re#:#)[1]
      Tx = event:attr("Tx")
    }
    
    if ent:temperature_readings{[SensorId, MessageId]} || ent:seen{SensorId}.as("Number") > value.as("Number") then
    noop()
    
    notfired{
      log debug timestamp
      log debug temperature
      log debug SensorId
      log debug MessageId
      ent:temperature_readings := ent:temperature_readings.defaultsTo({})
      ent:tracker := ent:tracker.defaultsTo({})
      ent:seen := ent:seen.defaultsTo({})
      ent:seen{SensorId} := ent:seen{SensorId}.defaultsTo(-1)
      ent:temperature_readings{[SensorId, MessageId]} :=  {"SensorId": SensorId, "MessageId": MessageId, "temperature" : temperature, "timestamp" : timestamp}
      ent:seen{SensorId} := value.as("Number") if value.as("Number") == (ent:seen{SensorId}.as("Number") + 1)
      ent:tracker{[Tx, SensorId]} := value.as("Number") if value.as("Number") > (ent:tracker{[Tx, SensorId]}.defaultsTo(-1).as("Number") + 1)
    }
    finally {
      raise gossip event "check_highest_seen" attributes { "value":value}
    }
  }
  
  rule highest_seen {
    select when gossip check_highest_seen
    foreach ent:temperature_readings{[event:attr("SensorId")]} setting(readings, stored_id)
    
        pre {
//      timestamp = event:attr("timestamp")
//      temperature = event:attr("temperature")
//      SensorId = event:attr("SensorId")
//      MessageId = event:attr("MessageId")
      value = event:attr("value")
      stored_value = stored_id.split(re#:#)[1]
    }
    
    if stored_value.as("Number") == value.as("Number") + 1 then
    noop()
    
    fired {
      ent:seen{SensorId} := stored_value.as("Number")
      raise gossip event "check_highest_seen" attributes {"value":(value.as("Number") + 1)} on final
    }
  }
  
  rule update_seen {
    select when gossip update_seen
//    foreach (Subscriptions:established("Tx_role","node") && Subscriptions:established("Rx_role","node"))  setting(x)
    
    pre {
      n = random:integer(lower = 0, upper = ((Subscriptions:established("Tx_role","node") && Subscriptions:established("Rx_role","node")).length() - 1))
      x = (Subscriptions:established("Tx_role","node") && Subscriptions:established("Rx_role","node"))[n]
    }
    
    event:send({
        "eci": x["Tx"], "eid": null,
        "domain": "gossip", "type": "seen",
        "attrs": {"seen":ent:seen,
        "Tx":x["Rx"]
        }
      }, host=x["Tx_host"].defaultsTo("http://localhost:8080"))
  }
  
rule get_seen {
    select when gossip seen where ent:processing == "on"
    
    pre{
      seen = event:attr("seen")
      Tx = event:attr("Tx")
    }
    
    if Subscriptions:established("Tx", Tx) then noop()
    
    fired {
      ent:tracker := ent:tracker.put([Tx],seen.defaultsTo({}))
      raise gossip event "updatetracker"
      raise gossip event "assemble_rumors" attributes { "Tx":Tx }
    }

  }
  
  
  rule rumor_assemble {
    select when gossip assemble_rumors
    foreach ent:seen setting(seen_value, seen_id)
    
    pre {
      Tx = event:attr("Tx")
    }
    
    fired {
      log debug seen_id
      log debug seen_value
      rumors = rumors.put(ent:tracker{Tx}.filter(function(v,k){k == seen_id && v < seen_value}).map(function(v,k){seen_value-v}))
      //log debug ent:tracker{[ent:tracker.keys().head(), seen_id]}.defaultsTo(-1)
    }
    finally {
      //rumors = rumors.map(function(v,k) {v.length() > 0}) on final
      raise gossip event "format_rumors"  attributes { "needed_rumors":rumors, "Tx":Tx } on final
      rumors = {} on final
    }
  }
  
  rule rumor_formatting {
    select when gossip format_rumors where event:attr("needed_rumors").length() > 0
    foreach event:attr("needed_rumors") setting(rumor_value, rumor_id)
    foreach 1.range(rumor_value.as("Number")) setting(iterator)
    
    pre {
      a = rumor_value.as("Number").klog("rumor_value")
      b = rumor_id.klog("rumor_id")
      it = iterator.klog("iterator")
      Tx = event:attr("Tx")
      rumor = ent:temperature_readings{[rumor_id, rumor_id + ":" + (ent:tracker{[Tx,rumor_id]}.as("Number") + 1)]}.klog("rumor")
      temperature = rumor{"temperature"}
      SensorId = rumor{"SensorId"}
      MessageId = rumor{"MessageId"}
      timestamp = rumor{"timestamp"}
      
      x = Subscriptions:established("Tx", Tx).head().klog("subscription")
    }
    
      fired {
        ent:tracker{[Tx,rumor_id]} := ent:tracker{[Tx,rumor_id]}.as("Number") + 1
        raise gossip event "send_rumor" attributes {
          "SensorId": SensorId, "MessageId": MessageId, "temperature" : temperature, "timestamp" : timestamp, "subscription":x
        }
      }
    
  }
}
