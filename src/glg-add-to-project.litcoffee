# glg-add-to-project
A dialog to allow one or more CMs to be added to a consult,
survey, meeting, or event.

    hummingbird = require 'hummingbird'
    hbOptions =
      scoreThreshold: 0.5
      secondarySortField: 'createDate'
      secondarySortOrder: 'desc'
      howMany: 10
    Polymer 'glg-add-to-project',

## Attributes
### cmids
The IDs of council members to be added to the selected project

### appName
The name to use to identify the application or feature used in ATC for tracking dashboard purposes

### rmPersonId
The person ID of the RM taking the ATC action on these experts on this selected project

### hb
Collection of hummingbird indexes, one per type of project entity

      hb:
        consults: new hummingbird()
        meetings: new hummingbird()
        surveys: new hummingbird()

## Change Handlers
### appNameChanged

      appNameChanged: ->
        #  @appName

### cmidsChanged

      cmidsChanged: ->
        #  @cmids

### rmPersonIdChanged

      rmPersonIdChanged: ->
        # @rmPersonId

### filtersChanged

      filtersChanged: (evt, detail, sender) ->
        # don't search until we're ready
        if detail.isSelected and @$.nectar? and @hb?
          @$.nectar.entities = detail.item.textContent if detail.item.parentElement.id is 'selectProjType'
          @search()

### queryUpdated

      queryUpdated: (evt, detail, sender) ->
        @query = detail.value
        @search()

## Events
### atp-started
fired when an expert is about to be added to a project

### atp-succeeded
fired after an expert was successfully added to a project

### atp-failed
fired after failing to add an expert to a project

## Methods
### getMyProjects
Fetch of names of projects created in the last 90 days
where this user was either primary or delegate RM or recruiter

      getMyProjects: (currentuser) ->

#### buildHbIndex
Builds a hummingbird index with the list of projects returned by core-ajax call to epiquery

        buildHbIndex = (entity) =>
          (data) =>
            # build hb index from data
            @hb[entity].add project for project in data
            console.log "hummingbird #{entity}: #{Object.keys(@hb[entity].metaStore.root).length} items"

#### getUrl
getUrl takes a single paramater which can be either a string (the url)
or an object, specifing url and timeout: {url:'http://myurl.com',timeout:1000}

        getJSONUrl = (url, timeout) ->
          new Promise (resolve,reject) ->
            request = new XMLHttpRequest
            request.async = false
            request.withCredentials = true
            request.responseType = 'json'
            request.timeout = timeout if timeout?
            request.ontimeout = () ->
              reject new Error "getUrl timed out fetching #{url}"
            request.onload = () ->
              console.log "response received from #{url}"
              resolve request.response
            request.onerror = () ->
              reject new Error "getUrl failed: #{request.response.statusText}"
            request.open 'GET', url
            request.send()

#### fetchEpiResults
Hits an epiquery url and returns the results if there are any

        fetchEpiResults = (url, timeout, callback) ->
          #Fetch and then process results
          console.log "Fetching #{url}"
          getJSONUrl url, timeout
          .then (output) ->
            if Array.isArray(output)
              callback if Array.isArray(output[output.length-1]) then output[output.length-1] else output
              Promise.resolve()
            else
              Promise.reject new Error("received unexpected result format")
          .then undefined, (err) ->
            Promise.reject new Error("fetchEpiResults failed: #{err}")

        # lastUpdate must be seconds since epoch for sql server
        # chosen to round off lastUpdate to the nearest day-ish
        lastUpdate = Math.floor((new Date(new Date() - 1000*60*60*24*90)).getTime()/(24*60*60*1000))*24*60*60
        # changing the URL triggers core-ajax fetch
        promisesArray = []
        timeout = 3*60*1000 # 3 min timeout
        myConsultsUrl = "http://mepiquery.glgroup.com/nectar/glgliveMalory/getConsultsDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{@rmPersonId ? currentuser.detail.personId}"
        mySurveysUrl = "http://mepiquery.glgroup.com/nectar/glgliveMalory/getSurveyDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{@rmPersonId ? currentuser.detail.personId}"
        myMeetingsUrl = "http://mepiquery.glgroup.com/nectar/glgliveMalory/getEventsGroupsVisitsDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{@rmPersonId ? currentuser.detail.personId}"
        promisesArray.push fetchEpiResults(myConsultsUrl, timeout, buildHbIndex 'consults')
        promisesArray.push fetchEpiResults(mySurveysUrl, timeout, buildHbIndex 'surveys')
        promisesArray.push fetchEpiResults(myMeetingsUrl, timeout, buildHbIndex 'meetings')
        Promise.all promisesArray
        .then undefined, (err) =>
          console.log "Failed to build hb indexes: #{err}"
        .then () =>
          @$.hbfetching.removeAttribute 'spinner'
          @$.hbfetching.setAttribute 'hidden', true
          @$.inputwrapper.removeAttribute 'class'
          @$.inputwrapper.focus()

### displayResults

      displayResults: (target) ->
        (results) ->
          target.$.projectMatches.model = {matches: results}

### displayNectarResults

      displayNectarResults: (evt, detail, sender) ->
        @displayResults(evt.target) detail.results.matches

### search
Primary function for retrieving typeahead results from either hummingbird or nectar

      #TODO: create multiple hummingbird indexes: consults, meetings, surveys
      search: () ->
        if @query? and @$.selectProjOwner?.selectedItem? and @$.selectProjType?.selectedItem?
          if @$.selectProjOwner.selectedItem.innerText is 'mine'
            if isNaN(@query)
              @hb[@$.nectar.entities].search @query, @displayResults(@), hbOptions
            else
              @hb[@$.nectar.entities].jump @query, @displayResults(@), hbOptions
          else
            if isNaN(@query)
              @$.nectar.query @query
            else
              @$.nectar.jump @query

### selectProject
Attaches the council member(s) to the selected project

      selectProject: () ->
        console.log "project selected #{@$.projects.value.name} (#{@$.projects.value.id})"
        #TODO: on successful add, display message to user

### prettyDate
Human readable formatted date string

      prettyDate: (d) ->
        d.toLocaleDateString()

## Polymer Lifecycle

      created: ->

      ready: ->
        @$.inputwrapper.setAttribute 'unresolved', ''
        console.log "cmids: #{@cmids}"
        console.log "appName: #{@appName}"
        console.log "rmPersonId: #{@rmPersonId}"

      attached: ->

      domReady: ->

      detached: ->

      publish:
        taskview:
          reflect: true
