ruleset manage_sensors {
  meta {
    use module io.picolabs.wrangler alias wrangler
    shares __testing, getChildren, nameFromID, sensors, sensorTemperatures
  }

  global {
    __testing = { "queries": [ { "name": "__testing" },
                                {"name": "nameFromID", "args": ["sensor_id"]},
                                {"name": "getChildren"},
                                {"name": "sensors"},
                                {"name": "sensorTemperatures"}],
                "events": [ { "domain": "sensor", "type": "new_sensor",
                            "attrs": [ "sensor_id"] },
                            { "domain": "collection", "type": "empty" },
                            { "domain": "sensor", "type": "unneeded_sensor",
                            "attrs": [ "sensor_id"] }] }

    nameFromID = function(sensor_id) {
      "Sensor " + sensor_id + " Pico"
    }

    getChildren = function() {
      wrangler:children()
    }

    sensors = function() {
      ent:sensors
    }

    defaultTemperature = function() {
      ent:default_threshold.defaultsTo(74)
    }

    sensorTemperatures = function() {
      sensors = getChildren();
      sensors.map(function(sensor) {
        eci = sensor{"eci"};
        args = {};
        wrangler:skyQuery(eci, "temperature_store", "temperatures", args);
      });
    }

  }

  rule sensor_already_exists {
    select when sensor new_sensor
    pre {
      sensor_id = event:attr("sensor_id")
      exists = ent:sensors >< sensor_id
    }
    if exists then
      send_directive("sensor_ready", {"sensor_id": sensor_id})
  }

  rule new_sensor {
    select when sensor new_sensor
    pre {
      sensor_id = event:attr("sensor_id")
      exists = ent:sensors >< sensor_id
    }
    if not exists
    then
      noop()
    fired {
      raise wrangler event "child_creation"
        attributes { "name": nameFromID(sensor_id),
                     "color": "#ffff00",
                     "sensor_id": sensor_id,
                     "rids": ["temperature_store", "wovyn_base", "sensor_profile"] }
    }
  }

  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      the_sensor = {"id": event:attr("id"), "eci": event:attr("eci")}
      sensor_id = event:attr("rs_attrs"){"sensor_id"}
    }
    if sensor_id.klog("found sensor_id")
    then
      noop()
    fired {
      ent:sensors := ent:sensors.defaultsTo({});
      ent:sensors{[sensor_id]} := the_sensor;
      raise sensor event "initialized"
        attributes {"sensor_id": sensor_id}
    }
  }

  rule initialized_event {
    select when sensor initialized
    pre {
      sensor_id = event:attr("sensor_id")
      name = nameFromID(sensor_id)
      smsNumber = 8017353755
      location = "logan apartment"
      sensor = ent:sensors{[sensor_id]}
      tempThreshold = defaultTemperature()
    }
    event:send({
      "eci": sensor{"eci"}, "eid": "initialize_profile",
      "domain": "sensor", "type": "profile_updated",
      "attrs": {"name": nameFromID(sensor_id), "location": location, "toPhoneNumber": smsNumber, "tempThreshold": tempThreshold}
    });
  }

  rule unneeded_sensor{
    select when sensor unneeded_sensor
    pre {
      sensor_id = event:attr("sensor_id")
      exists = ent:sensors >< sensor_id
      child_to_delete = nameFromID(sensor_id)
    }
    if exists then
      send_directive("deleting_sensor", {"sensor_id":sensor_id})
    fired {
      raise wrangler event "child_deletion"
        attributes {"name": child_to_delete};
      clear ent:sensors{[sensor_id]}
    }
  }

  rule collection_empty {
    select when collection empty
    always {
      ent:sensors := {}
    }
  }
}
