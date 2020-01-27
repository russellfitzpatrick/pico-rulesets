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
       results = http:get(base_url + "Messages.json", qs = {
                "PageSize":page
       }).decode() {"content"}.decode() {"messages"}
       resultsTo = (to.length() > 0) => results.filter(function(x) {x{"to"} == to}) | results
       resultsFrom = (from.length() > 0) => resultsTo.filter(function(x) {x{"from"} == from}) | resultsTo
       resultsFrom
    }
          __testing = { "queries": [ {"name": "__testing"}, {"name" : "messages", "args" : ["to", "from", "page"]}] }  

  }
}
