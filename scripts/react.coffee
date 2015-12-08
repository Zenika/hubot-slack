# Description:
#   Add a reaction for a regex
# Commands:
#   hubot reaction add <emoji> <regex> - add an error to fear
#   hubot reaction audittrails - list audit trails
#   hubot reaction list - list the feared errors
#   hubot reaction remove <#> - remove the reaction at the specified id

module.exports = (reaction) ->
  
  reactions = null
  cache = null

  loadConfiguration = () ->
    if reactions?
      return

    r = reaction.brain.get('reactions')
    if r?
      reactions = JSON.parse(r)
    else
      reactions = {list: [], audittrails: []}
      storeConfiguration()
    
    cache = []
    for candidate in reactions.list
      cache.push({e: candidate.e, r: new RegExp(candidate.m, 'i')})


  storeConfiguration = () ->
    reaction.brain.set('reactions', JSON.stringify(reactions))

  audittrail = (who, what) ->
    oneMonthAgo = new Date()
    oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1)
    while reactions.audittrails.length > 0 and reactions.audittrails[0].when.getTime() < oneMonthAgo.getTime()
      reactions.audittrails.splice(0, 1)
    reactions.audittrails.push {when: new Date(), who: who, what: what}
    
  reaction.brain.on 'loaded', ->
    loadConfiguration()

  react = (channel, ts, image, callback) ->
    reaction.http('https://slack.com/api/reactions.add?token=' + process.env.HUBOT_SLACK_TOKEN + 
                  '&name=' + image + 
                  '&channel=' + channel + 
                  '&timestamp=' + ts)
            .get()  (err, res, body) ->
              if callback?
                callback(body)
              return

  reaction.respond /reaction\s+add\s+([^\s]+)\s+(.*)$/, (res) ->
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
    for a in reactions.audittrails
      res.send a.when + ' / ' + a.who + ': ' + a.what

  reaction.respond /reaction\s+list$/, (res) ->
    i = 0
    for r in reactions.list
      res.send '#' + i++ + ':' + r.e + ':\t' + r.r

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

  loadConfiguration()

