# glg-add-to-project
An embeddable task list.

    epiquery2 = require 'epiquery2'
    hummingbird = require 'hummingbird'
    Polymer 'glg-add-to-project',

## Events

## Attributes and Change Handlers
### searchQuery
What we are looking for now. This is data bound driven.

      searchQueryChanged: ->
        @search()

### projectview
This is the name of the view currently selected.

### username
Who am I? Once we know a user, kick off a query to get all your tasks.

      usernameChanged: ->
        # TODO: this is where we define methods for persisting ATC to GLGLIVE database
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

## Methods
### findProject
This has a one time event handler to put cursor focus in the 'Find consultation' input box to allow data entry.

      findProject: ->
        if @taskview isnt 'your'
          hando = =>
            @removeEventListener 'onpage', hando
            @findProject()
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

##Event Handlers

###addToProject
To the database with you!

      addToProject: (evt, project) ->
        rules.validate project, @username
        @job project.guid, =>
          console.log 'save', expertId, projectId
          @epiclient.query 'glglive_o', 'todo/addTask.mustache', expertId, projectId
          @processTask undefined, expertId, projectId

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
        # TODO: is this where we'll attach to nectar?
        @epiclient = new epiquery2.EpiClient([
          "wss://nectar.glgroup.com/ws"
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
