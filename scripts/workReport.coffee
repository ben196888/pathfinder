HubotSlack = require('hubot-slack')
Spreadsheet = require('edit-google-spreadsheet')

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

  # yodiz bot format
  yodizRegex = /Recent activity in/
  robot.hear yodizRegex, (msg) ->
    if(workReportChannels.indexOf(get_channel(msg)) >= 0)
      robot.emit "work-report", msg
    
  robot.listeners.push new HubotSlack.SlackBotListener robot, yodizRegex, (msg) ->
    if(workReportChannels.indexOf(get_channel(msg)) >= 0)
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
