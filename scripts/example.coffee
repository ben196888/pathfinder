# Description:
#   This description shows up in the /help command
#
# Commands:
#   uppity? - prints out the count of the number of times somebody said "up"
#   bug me - secret surprise
#
# Notes:
#   https://github.com/github/hubot/blob/master/docs/scripting.md#documenting-scripts
#
# Author:
#   Michi Kono
#
HubotSlack = require('hubot-slack')
Spreadsheet = require('edit-google-spreadsheet')
# creds = Object.create(
#   'client_id': process.env.GOOGLE_CLIENT_ID
#   'client_secret': process.env.GOOGLE_CLIENT_SECRET
#   'refresh_token': process.env.GOOGLE_REFRESH_TOKEN)
creds = require('../oauth2.cred.json')
workReportChannels = require('../workReportChannels.json').channels

module.exports = (robot) ->
  # helper method to get sender of the message
  get_username = (response) ->
    "@#{response.message.user.name}"

  # helper method to get channel of originating message
  get_channel = (response) ->
    if response.message.room == response.message.user.name
      "@#{response.message.room}"
    else
      "##{response.message.room}"

  ###
  # basic example of a fully qualified command
  ###
  # responds to "[botname] sleep it off"
  # note that if you direct message this command to the bot, you don't need to prefix it with the name of the bot
  robot.respond /sleep it off/i, (msg) ->
    # responds in the current channel
    msg.send 'zzz...'

  ###
  # demo of brain functionality (persisting data)
  # https://github.com/github/hubot/blob/master/docs/scripting.md#persistence
  # counts every time somebody says "up"
  # prints out the count when somebody says "are we up?"
  ###
  # /STUFF/ means match things between the slashes. the stuff between the slashes = regular expression.
  # \b is a word boundary, and basically putting it on each side of a phrase ensures we are matching against
  # the word "up" instead of a partial text match such as in "sup"
  # robot.hear /\bup\b/, (msg) ->
    # note that this variable is *GLOBAL TO ALL SCRIPTS* so choose a unique name
    # robot.brain.set('everything_uppity_count', (robot.brain.get('everything_uppity_count') || 0) + 1)

  # ? is a special character in regex so it needs to be escaped with a \
  # the i on the end means "case *insensitive*"
  # robot.hear /are we up\?/i, (msg) ->
  #   msg.send "Up-ness: " + (robot.brain.get('everything_uppity_count') || "0")

  # A script to watch a channel's new members
  channel_to_watch = '#bot-test'
  robot.enter (msg) ->
    # limit our annoyance to this channel
    if(get_channel(msg) == channel_to_watch)
      # https://github.com/github/hubot/blob/master/docs/scripting.md#random
      msg.send msg.random ['welcome', 'hello', 'who are you?']

  # yodiz bot format
  yodizRegex = /Recent activity in/
  robot.hear yodizRegex, (msg) ->
    # if(workReportChannels.indexOf(get_channel(msg)) >= 0)
    robot.emit "work-report", msg
    
  robot.listeners.push new HubotSlack.SlackBotListener robot, yodizRegex, (msg) ->
    robot.emit "work-report", msg

  robot.on "work-report", (msg) ->
    try
      message = msg.message.text
      list = message.replace(/_/g, ' ').replace(/\*/g, ' ').split('\n')
      actionsList = []
      activity = {}
      activitiesList = []
      # Foreach row
      for item in list
        item = item.replace(/^\s+/, '').replace(/\s+$/, '')
        console.log item
        if item.indexOf('Recent') == 0
        # if item.startsWith('Recent')
          # Title handler
          console.log "In title handler"
          projectName = item.match(/Recent activity in\s+Project:\s+(.*)/)[1]
          console.log "Got project name: #{projectName}"
          # Push activity to activitiesList first
          if Object.keys(activity).length > 0
            activity['actions'] = actionsList
            actionsList = []
            console.log 'I push an activity'
            activitiesList.push activity
            activity = {}
          activity['projectName'] = projectName
        else if item.indexOf('>') == 0
        # else if item.startsWith('>')
          # Action handler
          console.log "In action handler"
          tmp = item.replace('>', '').split(' by ')
          if tmp.length == 2
            # Can parse action
            user = tmp[1].split('(')[0].replace(/\s+$/, '')
            content = tmp[0].replace(/\s+$/, '')
            action =
              user: user
              content: content
              data: null
            if content.match(/effort logged/i)
              # Effort action
              console.log "In effort parser"
              effort = content.split(':')[1].replace(/^\s+/, '')
              result = effort.match(/(([\d]+) hours)?\s?(([\d]+) minutes)?/)
              hours = parseInt(result[2]) or 0
              minutes = parseInt(result[4]) or 0
              console.log "I got effort"
              if activity.efforts
                activity.efforts['hours'] += hours
                activity.efforts['minutes'] += minutes
              else
                activity['efforts'] =
                  hours: hours
                  minutes: minutes
          else
            # Cannot parse action
            console.log "Cannot parse data G___G"
            action =
              user: null
              content: null
              data: item
          console.log "Push an action"
          actionsList.push action
        else
          # Task handler
          console.log "In task handler"
          continue if item == ''
          tmp = item.split('(')
          taskUrl = ''
          if tmp.length == 2
            taskUrl = tmp[1].replace(/\)\s+/, '')
          tmp = tmp[0].split(':')
          taskId = tmp[0].replace(/^\s+/, '').replace(/\s+$/, '')
          taskName = tmp[1].replace(/^\s+/, '').replace(/\s+$/, '')
          activity['task'] =
            url: taskUrl
            id: taskId
            name: taskName
      if Object.keys(activity).length > 0
        activity['actions'] = actionsList
        actionsList = []
        console.log 'I push an activity'
        activitiesList.push activity
        activity = {}
      robot.emit "send-report", {activity: a, msg: msg} for a in activitiesList.filter((x) -> x if x.efforts?)
      return
    catch error
      console.log error
  
  robot.on "send-report", (data) ->
    try
      activity = data.activity
      msg = data.msg
      project = activity.projectName
      user = activity.actions[0].user
      content = activity.task.name
      h = activity.efforts.hours
      m = activity.efforts.minutes
      effort = h + m/60.0

      spreadsheetId = '158nDB36KqKEFpWTn8DpuOtJM_vOpTMtys_RQeMAOJhI'
      worksheetName = 'SlackResponse'

      spreadsheetInfo =
        debug: true
        oauth2: creds
        spreadsheetId: spreadsheetId
        worksheetName: worksheetName

      Spreadsheet.load spreadsheetInfo, (err, spreadsheet) ->
        if err
          throw err
        # Get nextRow id
        spreadsheet.receive {getValues: false}, (err, rows, info) ->
          if err
            throw err
          nextRow = info.nextRow
          Spreadsheet.load spreadsheetInfo, (err, spreadsheet) ->
            if err
              throw err
            datetime = new Date
            row = {}
            row[nextRow] =
              1: datetime.toISOString()
              2: user
              3: project
              4: content
              5: effort
            spreadsheet.add row
            spreadsheet.send (err) ->
              if err
                throw err
              console.log "Project: #{project}, User: #{user}, Effort: #{effort} h"
              msg.send "Project: #{project}, User: #{user}, Effort: #{effort} h"
          return
        return
      return
    catch e
      console.log e
    
  ###
  # demo of replying to specific messages
  # replies to any message containing an "!" with an exact replica of that message
  ###
  # .* = matches anything; we access the entire matching string using match[0]
  # for using regex, use this tool: http://regexpal.com/
  robot.hear /.*!.*/, (msg) ->
    # send back the same message
    # reply prefixes the user's name in front of the text
    msg.reply msg.match[0]

  ###
  # Example of building an external endpoint (that lives on your heroku app) for others things to trigger your bot to do stuff
  # To see this in action, visit https://[YOUR BOT NAME].herokuapp.com/hubot/my-custom-url/:room after deploying
  # This could be used to let bots talk to each other, for example.
  # More on this here: https://github.com/github/hubot/blob/master/docs/scripting.md#http-listener
  ###
  # robot.router.get should probably be a .post to prevent spiders from making it fire
  # robot.router.get '/hubot/my-custom-url/:room', (req, res) ->
  #   robot.emit "bug-me", {
  #     room: req.params.room
  #     # note the REMOVE THIS PART in this example -- since we are using a GET and the link is being published in the chat room
  #     # it can cause an infinite loop since slack itself pre-fetches URLs it sees
  #     source: "a HTTP call to #{process.env.HEROKU_URL or ''}[/ REMOVE THIS PART ]/hubot/my-custom-url/#{req.params.room} (could be any room name)"
  #   }
  #   # reply to the browser
  #   res.send 'OK'

  ###
  # Secondary example of triggering a custom event
  # note that if you direct message this command to the bot, you don't need to prefix it with the name of the bot
  ###
  robot.respond /bug me/i, (msg) ->
    robot.emit "bug-me", {
      # removing the @ symbol
      room: get_username(msg).slice(1),
      source: 'use of the bug me command'
    }

  ###
  # A generic custom event listener
  # Also demonstrating how to send private messages and messages to specific channels
  # https://github.com/github/hubot/blob/master/docs/scripting.md#events
  ###
  robot.on "bug-me", (data) ->
    try
      # this will do a private message if the "data.room" variable is the user id of a person
      robot.messageRoom data.room, 'This is a custom message due to ' + data.source
    catch error

  ###
  # Demonstration of how to parse private messages
  ###
  # responds to all private messages with a mean remark
  # robot.hear /./i, (msg) ->
    # you can chain if clauses on the end of a statement in coffeescript to make things look cleaner
    # in a direct message, the channel name and author are the same
    # msg.send 'shoo!' if get_channel(msg) == get_username(msg)

  # any message above not yet processed falls here. See the console to examine the object
  # uncomment to test this
  # robot.catchAll (response) ->
  #   console.log('catch all: ', response)
