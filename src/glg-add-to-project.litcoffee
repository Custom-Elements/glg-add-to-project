# glg-add-to-project
A dialog to allow one or more CMs to be added to a consult,
survey, or various types of in-person meetings.

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

### displayUI
Toggles whether to display a UI at all, or to simply expose the component as an invisible service.

### displayOwnerFilter
Toggles whether to display the project owner filter in the UI.  Default: true

### displayProjType
Toggles whether to display the project type filter in the UI.  Default: true

### rmPersonId
The person ID of the RM taking the ATC action on these experts on this selected project

## Globals
### hb
Collection of hummingbird indexes, one per type of project entity

      hb:
        consults: new hummingbird()
        meetings: new hummingbird()
        surveys: new hummingbird()

## Events
### atp-started
fired when an expert is about to be added to a project

### atp-succeeded
fired after an expert was successfully added to a project

### atp-failed
fired after failing to add an expert to a project

## Methods
### filtersUpdated
Executes a new search when a different type of project is selected

      filtersUpdated: (evt, detail, sender) ->
        # don't search until we're ready
        if detail.isSelected and @$.nectar? and @hb?
          @$.nectar.entities = detail.item.textContent if detail.item.parentElement.id is 'selectProjType'
          @search()

### queryUpdated
Executes a new search with the new query

      queryUpdated: (evt, detail, sender) ->
        @query = detail.value
        @search()

### fetchEpiResults
Hits an epiquery url and returns the results if there are any

      fetchEpiResults: (url, timeout, callback) ->

#### getJSONUrl
getJSONUrl takes a single paramater which can be either a string (the url)
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

### getMyProjects
Fetch of names of projects created in the last 90 days
where this user was either primary or delegate RM or recruiter

      getMyProjects: (currentuser) ->
        fetchEpiResults = @fetchEpiResults

#### buildHbIndex
Builds a hummingbird index with the list of projects returned by core-ajax call to epiquery

        buildHbIndex = (entity) =>
          (data) =>
            # build hb index from data
            @hb[entity].add project for project in data
            console.log "hummingbird #{entity}: #{Object.keys(@hb[entity].metaStore.root).length} items"

        # lastUpdate must be seconds since epoch for sql server
        # chosen to round off lastUpdate to the nearest day-ish
        lastUpdate = Math.floor((new Date(new Date() - 1000*60*60*24*90)).getTime()/(24*60*60*1000))*24*60*60
        # changing the URL triggers core-ajax fetch
        promisesArray = []
        timeout = 3*60*1000 # 3 min timeout
        myConsultsUrl = "//mepiquery.glgroup.com/nectar/glgliveMalory/getConsultsDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{@rmPersonId ? currentuser.detail.personId}"
        mySurveysUrl = "//mepiquery.glgroup.com/nectar/glgliveMalory/getSurveyDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{@rmPersonId ? currentuser.detail.personId}"
        myMeetingsUrl = "//mepiquery.glgroup.com/nectar/glgliveMalory/getEventsGroupsVisitsDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{@rmPersonId ? currentuser.detail.personId}"
        promisesArray.push fetchEpiResults(myConsultsUrl, timeout, buildHbIndex 'consults')
        promisesArray.push fetchEpiResults(mySurveysUrl, timeout, buildHbIndex 'surveys')
        promisesArray.push fetchEpiResults(myMeetingsUrl, timeout, buildHbIndex 'meetings')
        Promise.all promisesArray
        .then undefined, (err) =>
          console.log "Failed to build hb indexes: #{err}"
        .then () =>
          @$.hbfetching.setAttribute 'hidden', true
          @$.inputwrapper.removeAttribute 'hidden' unless @hideUI
          @$.inputwrapper.focus()

### displayResults
Used by displayNectarResults and directly as a callback passed to hummingbird index queries.

      displayResults: (target) ->
        (results) ->
          target.$.projectMatches.model = {matches: results}

### displayNectarResults
Used to display nectar results and assumes that the results are interleaved, not grouped by entity.

      displayNectarResults: (evt, detail, sender) ->
        @displayResults(evt.target) detail.results.matches

### search
Primary function for retrieving typeahead results from either hummingbird or nectar

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
        selectedProject = @$.projects.value
        entity = @$.selectProjType.selectedItem.innerText

        # currently, we only track adds to consults
        track = (app=@appName, projId=selectedProject.id, cmIds=@cmids, rmId=@rmPersonId, action='add') =>
          url = "//services.glgresearch.com/trackingexpress/"
          url += "track/appName/#{app}/action/#{action}/personId/#{rmId}/consultationId/#{projId}/cmIds/[#{cmIds.split ','}]"
          request = new XMLHttpRequest
          request.withCredentials = true
          debugger
          #request.open 'GET', url
          #request.send()

        switch entity
          when 'consults'
            console.log "consult selected #{selectedProject.name} (#{selectedProject.id})"
            track()
          when 'surveys'
            console.log "survey selected #{selectedProject.name} (#{selectedProject.id})"
          when 'meetings'
            console.log "meeting selected #{selectedProject.name} (#{selectedProject.id})"
            url = "//query.glgroup.com/Event/attachCouncilMember.mustache?"
            url += "MeetingId=#{selectedProject.id}"
            url += "&PersonIds=#{_.map(selectedIds, (id) -> {PersonId: id})}"
            url += "&LastUpdatedBy=#{@rmPersonId}"

### prettyDate
Human readable formatted date string

      prettyDate: (d) ->
        d.toLocaleDateString()

## Polymer Lifecycle

      created: ->
        @hideUI = false

      ready: ->
        @$.inputwrapper.setAttribute 'unresolved', ''
        @$.hbfetching.setAttribute 'hidden', 'true' if @hideUI
        console.log "cmids: #{@cmids}"
        console.log "appName: #{@appName}"
        console.log "rmPersonId: #{@rmPersonId}"

      attached: ->

      domReady: ->

      detached: ->

      publish:
        taskview:
          reflect: true
