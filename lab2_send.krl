ruleset twilio.send {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides
        send_sms
    provides
        messages
  }
 
  global {
    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
                "From":from,
                "To":to,
                "Body":message
            })
    }

  
    messages = function(to, from, page) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:get(base_url + "Messages.json", qs = {
                "From":from,
                "To":to,
                "PageSize":page
       })
    }
  }
}
