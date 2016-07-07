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
        msg.send("```\n" +
                 "note help                          - show tips\n" +
                 "note list                          - list all nb in this channel\n" +
                 "note create <notebook>             - create a nb\n" + 
                 "note delete <notebook>             - delete a nb\n" +
                 "note show <notebook>               - show notes in the nb\n" + 
                 "note show                          - show notes in the nb recently used\n" +
                 "note addnt <some_notes>            - add note into the nb recently used\n" +
                 "note (notebook) addnt <some_notes> - add note into the nb\n" +
                 "note rmnt                          - remove last note in nb recently used\n" +
                 "note (notebook) rmnt               - remove last note in the nb\n" +
                 "note rmnt <note_id>                - remove note in the nb recently used\n" +
                 "note (notebook) rmnt <note_id>     - remove note in the nb\n" +
                 "```")

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
        nbName = ''
        nbName = content if content? and content != ''
        nbName = nbDict[channel][0] if nbName == '' and nbDict[channel].length > 0
        if nbName.match(/me the money/)
          msg.send "I have no money, don't rob me. :elf:"
          return
        index = nbDict[channel].indexOf(nbName)
        nbDict[channel].unshift(nbDict[channel].splice(index, 1)[0]) if index > 0
        if index < 0
          msg.send "No notebook available"
          return
        notebook = "#{channel}.#{nbName}"
        nb = robot.brain.get notebook
        content = nb.map((x) -> x.content)
        message = if content.length > 0 then content.reduce((pre, cur, curId) -> pre + '\n' + curId + ', ' + cur) else "Nothing here"
        msg.send message

      when "addnt"
        nbName = ''
        nbName = target if target? and target != ''
        nbName = nbDict[channel][0] if nbName == '' and nbDict[channel].length > 0
        index = nbDict[channel].indexOf(nbName)
        nbDict[channel].unshift(nbDict[channel].splice(index, 1)[0]) if index > 0
        if index < 0
          msg.send "No notebook available"
          return
        notebook = "#{channel}.#{nbName}"
        note =
          user: user
          content: content
        ntList = robot.brain.get notebook
        robot.brain.set notebook, ntList
        ntList.push(note)
        msg.send "note added"

      when "rmnt"
        nbName = ''
        nbName = target if target? and target != ''
        nbName = nbDict[channel][0] if nbName == '' and nbDict[channel].length > 0
        index = nbDict[channel].indexOf(nbName)
        nbDict[channel].unshift(nbDict[channel].splice(index, 1)[0]) if index > 0
        if index < 0
          msg.send "No notebook available"
          return
        notebook = "#{channel}.#{nbName}"
        ntList = robot.brain.get notebook
        ntId = ntList.length - 1
        ntId = parseInt(content.match(/(\d+)/)[0]) if content? and content != '' and content.match(/(\d+)/)
        if ntId < 0
          msg.send "No note is removable"
          return
        ntList.splice(ntId, 1) if ntId >= 0
        msg.send "note removed"

      else
        msg.send "I don't know what I should do."