# Description:
#   Add a reaction for a regex
# Commands:
#   hubot reaction add <:emoji:> <regex> - add a reaction for the specified regex (case insensitive)
#   hubot reaction audittrails - list audit trails
#   hubot reaction list - list the reactions
#   hubot reaction remove <#> - remove the reaction at the specified id

module.exports = (reaction) ->
  
  reactions = null
  cache = null

  loadConfiguration = () ->
    if reactions?
      return

    reactions = reaction.brain.data.reactions or null
    if reactions == null
      reactions = {list: [], audittrails: []}
      storeConfiguration()
    
    cache = []
    for candidate in reactions.list
      cache.push({e: candidate.e, r: new RegExp(candidate.r, 'i')})


  storeConfiguration = () ->
    reaction.brain.data.reactions = reactions

  audittrail = (who, what) ->
    oneMonthAgo = new Date()
    oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1)
    oneMonthAgo = oneMonthAgo.getTime()

    while reactions.audittrails.length > 0 and reactions.audittrails[0].when < oneMonthAgo
      reactions.audittrails.splice(0, 1)
    reactions.audittrails.push {when: new Date().getTime(), who: who, what: what}
    
  reaction.brain.on 'loaded', ->
    loadConfiguration()

  react = (channel, ts, image, callback) ->
    reaction.http('https://slack.com/api/reactions.add?token=' + process.env.HUBOT_SLACK_TOKEN + 
                  '&name=' + image + 
                  '&channel=' + channel + 
                  '&timestamp=' + ts)
            .get()  (err, res, body) ->
              if body and body.ok == "false"
                console.log body
              
              if callback?
                callback(body)
              return

  reaction.respond /reaction\s+add\s+:([^:]+):\s+(.*)$/, (res) ->
    message = res.message
    react message.rawMessage.channel, message.rawMessage.ts, res.match[1], (body) ->
      result = JSON.parse(body)
      if result and result.ok
        reactions.list.push {e: res.match[1], r: res.match[2]}
        cache.push {e: res.match[1], r: new RegExp(res.match[2], 'i')}
        audittrail res.message.user.name, 'added ' + res.match[2]
        storeConfiguration()
        res.send res.match[2] + ' will trigger :' + res.match[1] + ':'
      else
        res.send 'emoji ' + res.match[1] + ' does not exist (' + result.error + ')'


  reaction.respond /reaction\s+audittrails$/, (res) ->
    buffer = 'audit trails: \n'
    for a in reactions.audittrails
      buffer += a.when + ' / ' + a.who + ': ' + a.what + '\n'
    res.send buffer

  reaction.respond /reaction\s+list$/, (res) ->
    i = 0
    buffer = 'current rules: \n'
    for r in reactions.list
      buffer += '#' + i++ + ':' + r.e + ':\t' + r.r '\n'
    res.send buffer

  reaction.respond /reaction\s+remove\s([0-9]+)$/, (res) ->
    index = new Number(res.match[1])
    if index < 0 or index >= reactions.list.length
      return
    backup = reactions.list[index]
    reactions.list.splice(index, 1)
    cache.splice(index, 1)
    audittrail res.message.user.name, 'removed ' +  backup.r
    storeConfiguration()
    res.send backup.r + ' has been removed'

  reaction.hear /^./, (res) ->
    message = res.message
    if message.match /^([^ ]+\s+)reaction /
      return

    for candidate in cache
      if message.match candidate.r
        react message.rawMessage.channel, message.rawMessage.ts, candidate.e

