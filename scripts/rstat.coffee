# Description:
#   The bot will count and display some stats about the emoji.
# Commands:
#   hubot rstat - Give the reactions stats for the current channel
#   hubot rstat user <@user> - Give the current channel's reactions stats used to react at <@user> messages
#   hubot rstat limit <number> - Set the displayed emoji's limit.

module.exports = (robot) ->

    reactions = {};
    limit = 5


################ STATS FOR A CHANNEL ##############
################       GLOBAL        ##############

    robot.respond /rstat$/, (res) ->
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
      for emoji, index in sortedList
        if(index < limit)
          stream += ":"+emoji+": -> "+reactions[emoji]+" \n"

      if(stream == "")
        stream = "No emoji detected for this user within the last 1000 messages";
      res.send stream ;

    analyzeMessage = (message, userId) ->
      if(message.reactions)
        shouldAnalyze = true;
        if(userId)
          shouldAnalyze = (message.user == userId);
        if(shouldAnalyze)
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


################       By Users        ##############

    robot.respond /rstat user @?[a-zA-Z0-9]+/, (res) ->
      channelId = res.message.rawMessage.channel;
      user = res.message.rawText.split(' ')[3];
      user = user.slice(2,-1);
      reactions = {};
      getChannelMessages channelId, (response) ->
        for message in response.messages
          analyzeMessage message, user
        outputReactions res, reactions

    robot.respond /rstat limit [0-9]+/, (res) ->
      limit = res.message.rawText.split(' ')[3];
      res.send("Displayed emoji's limit set to "+limit);
