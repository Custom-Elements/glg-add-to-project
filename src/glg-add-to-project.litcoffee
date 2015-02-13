# glg-add-to-project
A dialog to allow one or more CMs to be added to a consult,
survey, meeting, or event.

    hummingbird = require 'hummingbird'
    Polymer 'glg-add-to-project',

## Attributes and Change Handlers
### searchQuery
What we are looking for now. This is data bound driven.

### hb
Hummingbird index of all user's recent projects.

## Events
### searchQueryChanged
Get typeahead results for project names containing searchQuery.

      searchQueryChanged: ->
        @search()


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

      # once epiquery returns with projects, build hummingbird index
      myprojectsResponse: (data) ->
        # build hb index from data
        hb = new hummingbird()
        hb.add project for project in data.detail.response

      # trigger fetch of names of projects created in the last 90 days
      # where this user was either primary or delegate RM or recruiter
      getMyProjects: () ->
        user = @shadowRoot.querySelector 'glg-current-user#atp-user'
        projHandler = @shadowRoot.querySelector 'core-ajax#myprojects'
        user.addEventListener 'user', (currentuser) ->
          # lastUpdate must be seconds since epoch for sql server
          lastUpdate = Math.floor((new Date(new Date() - 1000*60*60*24*90)).getTime()/(60*1000))*60
          #projHandler.url = "http://mepiquery.glgroup.com/cache10m/nectar/glgliveMalory/getConsultsDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{currentuser.detail.personId}"
          projHandler.url = "http://mepiquery.glgroup.com/cache10m/nectar/glgliveMalory/getConsultsDelta.mustache?lastUpdate=#{lastUpdate}&personId=202654"


##Event Handlers

###addToProject
To the database with you!

      addToProject: (evt, project) ->
        rules.validate project, @username
        @job project.guid, =>
          console.log 'save', expertId, projectId

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
        @getMyProjects()
        template = @shadowRoot.querySelector 'template#projectMatches'
        (@shadowRoot.querySelector 'ui-typeahead#projects').addEventListener 'inputchanged', (evt) ->
          @hb.search evt.detail.value, (results) ->
            template.model = results
            Platform.performMicrotaskCheckpoint()


Hooking up to epistream. Each row coming back gets processed the same from
the server as from the client.

      attached: ->

      domReady: ->

      detached: ->

      publish:
        taskview:
          reflect: true
