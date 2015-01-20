#glg-doit
An embeddable task list.

    _ = require 'lodash'
    rules = require './rules.litcoffee'
    epiquery2 = require 'epiquery2'
    hummingbird = require 'hummingbird'
    Polymer 'glg-doit',

##Events

##Attributes and Change Handlers
###searchstring
What we are looking for now. This is data bound driven.

      searchstringChanged: ->
        @search()

###taskview
This is the name of the view currently selected.

###username
Who am I? Once we know a user, kick off a query to get all your tasks.

      usernameChanged: ->
        @epiclient.query 'glglive_o', 'todo/list.mustache',
          username: @username
        @epiclient.query 'glglive_o', 'todo/doneList.mustache',
          username: @username
        clearInterval @updatePoll
        @updatePoll = setInterval =>
          if @next_baseline
            @epiclient.query 'glglive_o', 'todo/listChanges.mustache',
              username: @username
              next_baseline: @next_baseline
            , 'poll'
        , 1000

##Methods
###addTodo
Adding a todo will check for a 'your' task that is blank to avoid a long
string of blank tasks. Otherwise -- it just pushes a new task on the list.

This has a one time event handler to make sure we are on the 'your' tab
to allow data entry.

      addTodo: ->
        if @taskview isnt 'your'
          hando = =>
            @removeEventListener 'onpage', hando
            @addTodo()
          @addEventListener 'onpage', hando
          @taskview = 'your'
          return
        focusOnBlankElement = =>
          taskElements = @shadowRoot.querySelectorAll('#your glg-task').array()
          for taskElement in taskElements
            if not taskElement.templateInstance.model.task.what
              taskElement.focus()
              return true
          false
        if not focusOnBlankElement()
          @data.your.unshift
            who: @username
          @async focusOnBlankElement

###todoNumber
All about formatting the number of todos, which really means defaulting.

      todoNumber: (value) ->
        value or 0

##Event Handlers
###processTask
Process any update to a task. No distinction is made from a local task change
or a remote one coming in from the server. So, changes or edits fire off a
`task` event locally, which is shuffled out to the server. Count on the server
to de-dupe and prevent a task event from ping-pong looping.

A single buffer of objects is kept and updated, then managed in lists for
display.

The main thing is to move the task into the right view list, todo, delegated, done.

A task is todo if you made it, or it was delegated to you by someone else.

A task is delegated if you made it and delegated it to someone else.

Any done task is just that.

Any other task isn't your problem!

      processTask: (evt, task) ->
        @next_baseline = task.next_baseline or @next_baseline
        rules.validate task, @username
        @data = @data or {}
        @data.your = @data.your or []
        @data.delegated = @data.delegated or []
        @data.done = @data.done or []
        @data.all = @data.all or {}

        if @data.all[task.guid]
          task = _.extend @data.all[task.guid] or {}, task
        else
          @data.all[task.guid] = task

        if task.done
          _.remove @data.delegated, (x) -> x.guid is task.guid
          _.remove @data.your, (x) -> x.guid is task.guid
          if not _.any(@data.done, (x) -> x.guid is task.guid)
            @data.done.push task
        else if rules.delegatedOut task, @username
          _.remove @data.your, (x) -> x.guid is task.guid
          _.remove @data.done, (x) -> x.guid is task.guid
          if not _.any(@data.delegated, (x) -> x.guid is task.guid)
            @data.delegated.push task
        else if rules.forMe task, @username
          _.remove @data.delegated, (x) -> x.guid is task.guid
          _.remove @data.done, (x) -> x.guid is task.guid
          if not _.any(@data.your, (x) -> x.guid is task.guid)
            @data.your.push task
        else
          _.remove @data.your, (x) -> x.guid is task.guid
          _.remove @data.delegated, (x) -> x.guid is task.guid
          _.remove @data.done, (x) -> x.guid is task.guid

###processTaskDelete
This one is a bit simpler than a normal update, just pull it from the lists.

      processTaskDelete: (evt, task) ->
        console.log 'delete', task
        delete @data.all[task.guid]
        _.remove @data.delegated, (x) -> x.guid is task.guid
        _.remove @data.your, (x) -> x.guid is task.guid
        _.remove @data.done, (x) -> x.guid is task.guid
        @epiclient.query 'glglive_o', 'todo/deleteTask.mustache', task

###processTaskSave
To the database with you!

      processTaskSave: (evt, task) ->
        rules.validate task, @username
        @job task.guid, =>
          console.log 'save', task
          @epiclient.query 'glglive_o', 'todo/addTask.mustache', task
          @processTask undefined, task

###search
Process a search, this will:
* make sure there is a current index, leveraging the `@next_revision` from SQL
* search the index for an array of tasks
* swap the UI out with a data bound list or search results

      search: (evt) ->
        if (@index?.at_revision or 0) isnt @next_baseline
          @index = new hummingbird.Index()
          @index.at_revision = @next_baseline or 0
          Object.keys(@data.all).forEach (guid) =>
            task = @data.all[guid]
            @index.add
              id: guid
              name: "#{task.what} #{task.who}"
              task: task
        if @$.search.value?.trim()
          @index.search @$.search.value, (results) =>
            @data.search = results.map (x) -> x.task
            @taskview = 'search'
        else
          @taskview = 'your'

##Polymer Lifecycle

      created: ->

      ready: ->

Hooking up to epistream. Each row coming back gets processed the same from
the server as from the client.

      attached: ->
        @taskview = 'your'
        @epiclient = new epiquery2.EpiClient([
          "wss://services.glgresearch.com/epistream-consultations-clustered/sockjs/websocket"
          "wss://east.glgresearch.com/epistream-consultations-clustered/sockjs/websocket"
          "wss://west.glgresearch.com/epistream-consultations-clustered/sockjs/websocket"
          "wss://europe.glgresearch.com/epistream-consultations-clustered/sockjs/websocket"
          "wss://asia.glgresearch.com/epistream-consultations-clustered/sockjs/websocket"
          ]);
        @epiclient.on 'row', (row) =>
          @processTask undefined, row.columns
        @epiclient.on 'error', ->
          console.log arguments

      domReady: ->

      detached: ->

      publish:
        taskview:
          reflect: true
