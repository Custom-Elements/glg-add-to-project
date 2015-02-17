# glg-add-to-project
A dialog to allow one or more CMs to be added to a consult,
survey, meeting, or event.

    hummingbird = require 'hummingbird'
    Polymer 'glg-add-to-project',

## Attributes and Change Handlers

## Events

## Methods
### myprojectsResponse
Builds a hummingbird index with the list of projects returned by core-ajax call to epiquery

      myprojectsResponse: (data) ->
        # build hb index from data
        @hb = new hummingbird()
        @hb.add project for project in data.detail.response
        console.log "hummingbird ready"
        @attachResultListener @hb

### getMyProjects
Fetch of names of projects created in the last 90 days
where this user was either primary or delegate RM or recruiter

      getMyProjects: () ->
        user = @shadowRoot.querySelector 'glg-current-user#atp-user'
        projHandler = @shadowRoot.querySelector 'core-ajax#myprojects'
        user.addEventListener 'user', (currentuser) ->
          # lastUpdate must be seconds since epoch for sql server
          lastUpdate = Math.floor((new Date(new Date() - 1000*60*60*24*90)).getTime()/(60*1000))*60
          #projHandler.url = "http://mepiquery.glgroup.com/cache10m/nectar/glgliveMalory/getConsultsDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{currentuser.detail.personId}"
          #markert 881448
          projHandler.url = "http://mepiquery.glgroup.com/cache10m/nectar/glgliveMalory/getConsultsDelta.mustache?lastUpdate=#{lastUpdate}&personId=881448"
          console.log "projHandler.url set"

### attachResultListener
Attach listener for inputchange, so we can execute a hummingbird search

      attachResultListener: (hb) ->
        template = @shadowRoot.querySelector 'template#projectMatches'
        input = @shadowRoot.querySelector 'ui-typeahead#projects'
        hbOpts =
          scoreThreshold: 0.5
          secondarySortField: 'createDate'
          secondarySortOrder: 'desc'
        input.addEventListener 'inputchange', (evt) ->
          hb.search evt.detail.value, (results) ->
            template.model = {matches: results}
            console.log "hb results processed"
            Platform.performMicrotaskCheckpoint()
          , hbOpts

### prettyDate
Human readable formatted date string

      prettyDate: (d) ->
        d.toLocaleDateString()

## Event Handlers
### addToProject
To the database with you!

      addToProject: (evt, project) ->
        rules.validate project, @username
        @job project.guid, =>
          console.log 'save', expertId, projectId


## Polymer Lifecycle

      created: ->
        @searchQuery = ""
        @hb = {}

      ready: ->
        @getMyProjects()

      attached: ->

      domReady: ->

      detached: ->

      publish:
        taskview:
          reflect: true
