module.exports = (robot) ->
  get_username = (response) ->
    "@#{response.message.user.name}"

  get_channel = (response) ->
    if response.message.room == response.message.user.name
      "@#{response.message.room}"
    else
      "##{response.message.room}"

  robot.hear /note\s?(\((.*)\))?\s?(\w+)(.*)/, (msg) ->
    channel = get_channel(msg)
    user = get_username(msg)
    try
      target = msg.match[2].replace(/^\s+/, '').replace(/\s+$/, '') if msg.match[2]?
      action = msg.match[3]
      content = msg.match[4].replace(/^\s+/, '').replace(/\s+$/, '') if msg.match[4]?
    catch err
      msg.send "Parse Error"
      return
    defaultName = 'default'
    nbDict = robot.brain.get('notebook')
    nbDict?= {}
    robot.brain.set('notebook', nbDict)
    nbDict[channel]?= []
    switch action
      when "help"
        # Ignore target
        msg.send("note help\n" +
                 "note list\n" +
                 "note create <notebook>\n" + 
                 "note delete <notebook>\n" +
                 "note show <notebook>\n" + 
                 "note show\n" +
                 "note addnt <some_notes>\n" +
                 "note (notebook) addnt <some_notes>")

      when "list"
        # Ignore target
        if nbDict[channel].length == 0
          msg.send "No notebook in this channel"
        else
          msg.send nbDict[channel].toString()

      when "create"
        # Ignore target
        nbName = content
        nbName = defaultName if nbName == ''
        tmpName = nbName
        i = 0
        while nbDict[channel].indexOf(tmpName) >= 0
          tmpName = nbName + i.toString()
          i++
        nbName = tmpName
        nbDict[channel].unshift(nbName)
        notebook = "#{channel}.#{nbName}"
        robot.brain.set(notebook, [])
        msg.send "Notebook #{nbName} created"

      when "delete"
        # Ignore target
        nbName = content
        index = nbDict[channel].indexOf(nbName)
        if index >= 0
          notebook = "#{channel}.#{nbName}"
          robot.brain.remove notebook
          nbDict[channel].splice(index, 1)
          msg.send "Notebook #{nbName} deleted"
        else
          msg.send "No notebook named #{nbName}"

      when "show"
        # Ignore target
        nbName = if content? and content != '' then content else nbDict[channel][0]
        index = nbDict[channel].indexOf(nbName)
        if index >= 0
          nbDict[channel].unshift(nbDict[channel].splice(index, 1)[0]) if index > 0
          notebook = "#{channel}.#{nbName}"
          nb = robot.brain.get notebook
          msg.send nb.map((x) -> x.content).toString()
        else
          msg.send "No notebook named #{nbName}"

      when "addnt"
        if target? and target != ''
          index = nbDict[channel].indexOf(target)
          if index < 0
            msg.send "No notebook named #{target}"
            return
          nbDict[channel].unshift(nbDict[channel].splice(index, 1)[0]) if index > 0
        if nbDict[channel].length <= 0
          msg.send "No notebook available"
          return
        nbName = nbDict[channel][0]
        notebook = "#{channel}.#{nbName}"
        note =
          user: user
          content: content
        nbList = robot.brain.get notebook
        robot.brain.set notebook, nbList
        nbList.push(note)
        msg.send "note added"

      else
        msg.send "I don't know what should I do."