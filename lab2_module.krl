ruleset twilio.module {
  meta {
    use module twilio.keys
    use module twilio.send alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
  } 


  rule test_send_sms {
    select when test new_message
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                    )
  }
  
    rule test_get_sms {
    select when test results
    send_directive("say", {"something": twilio:messages(event:attr("to").defaultsTo(""),
                                                        event:attr("from").defaultsTo(""),
                                                        event:attr("page").defaultsTo(50))})
  }
}
