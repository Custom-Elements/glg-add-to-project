# glg-add-to-project
A dialog to allow one or more CMs to be added to a consult,
survey, meeting, or event.

    hummingbird = require 'hummingbird'
    Polymer 'glg-add-to-project',

## Attributes
### cmids
The IDs of council members to be added to the selected project

### appName
The name to use to identify the application or feature used in ATC for tracking dashboard purposes

### rmPersonId
The person ID of the RM taking the ATC action on these experts on this selected project

## Change Handlers

## Events

## Methods
### myprojectsResponse
Builds a hummingbird index with the list of projects returned by core-ajax call to epiquery

      myprojectsResponse: (data) ->
        # build hb index from data
        @hb = new hummingbird()
        @hb.add project for project in data.detail.response
        @attachResultListener @hb
        console.log "hummingbird ready: #{Object.keys(@hb.metaStore.root).length} projects"
        @$.spinner.removeAttribute 'class'
        @$.spinner.setAttribute 'hidden', true
        @$.projects.removeAttribute 'class'

### getMyProjects
Fetch of names of projects created in the last 90 days
where this user was either primary or delegate RM or recruiter

      getMyProjects: () ->
        myprojects = @$.myprojects
        rmPersonId = @rmPersonId
        @$.atpuser.addEventListener 'user', (currentuser) ->
          # lastUpdate must be seconds since epoch for sql server
          lastUpdate = Math.floor((new Date(new Date() - 1000*60*60*24*90)).getTime()/(60*1000))*60
          myprojects.url = "http://mepiquery.glgroup.com/cache10m/nectar/glgliveMalory/getConsultsDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{rmPersonId ? currentuser.detail.personId}"
          console.log "projHandler.url set: #{myprojects.url}"

### attachResultListener
Attach listener for inputchange, so we can execute a hummingbird search

      attachResultListener: (hb) ->
        template = @$.projectMatches
        input = @$.projects
        hbOpts =
          scoreThreshold: 0.5
          secondarySortField: 'createDate'
          secondarySortOrder: 'desc'
        input.addEventListener 'inputchange', (evt) ->
          hb.search evt.detail.value, (results) ->
            template.model = {matches: results}
            console.log "hb results processed: #{results.length}"
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
        @hb = {}

      ready: ->
        @$.projects.setAttribute 'unresolved', ''
        @getMyProjects()
        console.log "cmids: #{@cmids}"
        console.log "appName: #{@appName}"
        console.log "rmPersonId: #{@rmPersonId}"

      attached: ->

      domReady: ->

      detached: ->

      publish:
        taskview:
          reflect: true
