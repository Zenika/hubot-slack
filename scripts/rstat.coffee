# Description:
#   The bot will count and display some stats about the emoji.
# Commands:
#   hubot rstat - Give the reactions stats for the current channel

module.exports = (robot) ->

    reactions = {};

    robot.respond /rstat/, (res) ->
      channelId = res.message.rawMessage.channel;
      reactions = {};
      getChannelMessages channelId, (response) ->
        for message in response.messages
          analyzeMessage message
        outputReactions res, reactions

    outputReactions = (res, reactions) ->
      sortedList = (Object.keys reactions).sort (a,b) ->
        return reactions[b]-reactions[a]
      stream = ""
      for emoji in sortedList
        stream += ":"+emoji+": -> "+reactions[emoji]+" \n"

      res.send stream ;

    analyzeMessage = (message) ->
      if(message.reactions)
        for reaction in message.reactions
          countReaction reaction

    countReaction = (reaction) ->
      if(reactions[reaction.name])
        reactions[reaction.name] += reaction.count
      else
        reactions[reaction.name] = reaction.count

    getChannelMessages = (channelId, callback) ->
      robot.http('https://slack.com/api/channels.history?token=' + process.env.HUBOT_SLACK_TOKEN +
                  '&channel=' + channelId +
                  '&count=1000')
            .get()  (err, res, body) ->
              if body and body.ok == "false"
                console.log body

              if callback?
                callback(JSON.parse(body))
              return
