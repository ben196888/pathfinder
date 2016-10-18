HubotSlack = require('hubot-slack')
Spreadsheet = require('edit-google-spreadsheet')
parse = require('csv-parse/lib/sync')

creds = require('../oauth2.cred.json')
workReportSettings = require('../workReportSettings.json')
workReportChannels = []

for channel in Object.keys(workReportSettings)
  if workReportChannels.indexOf(channel) < 0
    workReportChannels.push(channel)

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

  # yodiz bot format
  yodizRegex = /Recent activity in/
  robot.hear yodizRegex, (msg) ->
    channelName = get_channel(msg)
    if(workReportChannels.indexOf(channelName) >= 0 && workReportSettings[channelName].formats.indexOf(yodiz))
      robot.emit "yodiz-work-report", msg, workReportSettings[channelName]
    
  robot.listeners.push new HubotSlack.SlackBotListener robot, yodizRegex, (msg) ->
    channelName = get_channel(msg)
    if(workReportChannels.indexOf(channelName) >= 0 && workReportSettings[channelName].formats.indexOf(yodiz))
      robot.emit "yodiz-work-report", msg, workReportSettings[channelName]

  csvRegex = /log:/
  robot.hear csvRegex, (msg) ->
    channelName = get_channel(msg)
    if(workReportChannels.indexOf(channelName) >= 0 && workReportSettings[channelName].formats.indexOf(csv))
      robot.emit "csv-work-report", msg, workReportSettings[channelName]

  robot.listeners.push new HubotSlack.SlackBotListener robot, csvRegex, (msg) ->
    channelName = get_channel(msg)
    if(workReportChannels.indexOf(channelName) >= 0 && workReportSettings[channelName].formats.indexOf(csv))
      robot.emit "csv-work-report", msg, workReportSettings[channelName]

  robot.on "yodiz-work-report", (msg, channel) ->
    try
      message = msg.message.text
      list = message.replace(/_/g, ' ').replace(/\*/g, ' ').split('\n')
      actionsList = []
      activity = {}
      activitiesList = []
      # Foreach row
      for item in list
        item = item.replace(/^\s+/, '').replace(/\s+$/, '')
        # console.log item
        if item.indexOf('Recent') == 0
        # if item.startsWith('Recent')
          # Title handler
          # console.log "In title handler"
          projectName = item.match(/Recent activity in\s+Project:\s+(.*)/)[1]
          # console.log "Got project name: #{projectName}"
          # Push activity to activitiesList first
          if Object.keys(activity).length > 0
            activity['actions'] = actionsList
            actionsList = []
            # console.log 'I push an activity'
            activitiesList.push activity
            activity = {}
          activity['projectName'] = projectName
        else if item.indexOf('>') == 0
        # else if item.startsWith('>')
          # Action handler
          # console.log "In action handler"
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
              # console.log "In effort parser"
              effort = content.split(':')[1].replace(/^\s+/, '')
              result = effort.match(/(([\d]+) hours?)?\s?(([\d]+) minutes?)?/)
              hours = parseInt(result[2]) or 0
              minutes = parseInt(result[4]) or 0
              # console.log "I got effort"
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
          # console.log "Push an action"
          actionsList.push action
        else
          # Task handler
          # console.log "In task handler"
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
        # console.log 'I push an activity'
        activitiesList.push activity
        activity = {}
      robot.emit "send-report", {activity: a, msg: msg, channel: channel} for a in activitiesList.filter((x) -> x if x.efforts?)
      return
    catch error
      console.log error
  
  robot.on "csv-work-report", (msg, channel) ->
    try
      csvRegex = /^log:\s?(.{1,})/
      message = msg.message.text.trim()
      csvArray = csvRegex.exec(message)
      if csvArray
        # result is a 2D array
        result = parse(csvArray[1])
        # <projectName>, <loggedHours>, <completionDate>, <content>
        for row in result
          activity =
            datatime: null
            projectName: null
            user: null
            content: null
            efforts:
              hours: 0
              minutes: 0
          activity.user = get_username(msg)
          activity.projectName = row[0]
          activity.efforts.hours = row[1]
          activity.datetime = (new Date(row[2])).toISOString()
          activity.content = row[3]
          robot.emit "send-report", {activity: activity, msg: msg, channel: channel}
    catch error
      console.log error

  robot.on "send-report", (data) ->
    try
      today = new Date
      activity = data.activity
      msg = data.msg
      channel = data.channel
      datatime = activity.datetime || today.toISOString()
      project = activity.projectName
      user = activity.user || activity.actions[0].user
      content = activity.content || activity.task.name
      h = activity.efforts.hours
      m = activity.efforts.minutes
      effort = h + m/60.0
      spreadsheetInfo =
        debug: true
        oauth2: creds
        spreadsheetId: channel.spreadSheetId
        worksheetName: channel.worksheetName
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
            row = {}
            row[nextRow] =
              1: datetime
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
