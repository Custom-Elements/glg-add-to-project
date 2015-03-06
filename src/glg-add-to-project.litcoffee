# glg-add-to-project
A dialog to allow one or more CMs to be added to a consult,
survey, or various types of in-person meetings.

    hummingbird = require 'hummingbird'
    hbOptions =
      scoreThreshold: 0.5
      secondarySortField: 'createDate'
      secondarySortOrder: 'desc'
      howMany: 10
    epiquery2 = require 'epiquery2'
    epiUrlTemplate = ".glgresearch.com/epistream-consultations-clustered/sockjs/websocket"
    episervers = ("wss://#{region}#{epiUrlTemplate}" for region in ['services','asia','east','europe','west'])
    epi = new epiquery2.EpiClient episervers

    Polymer 'glg-add-to-project',

## Attributes
### cmIds
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
        consults: new hummingbird
        meetings: new hummingbird
        surveys: new hummingbird


## Attribute Change Handlers
### cmIdsChanged

      cmIdsChanged: (oldVal, newVal) ->
        uri = "councilMember/getCouncilMemberBrief.mustache"
        post =
          councilMemberIds: newVal.split ','
        @postToEpiquery uri, post, 15*1000
        .then undefined, (err) =>
          console.error "#{err}"
          Promise.reject()
        .then (messages) =>
          @councilMembers[cmData.councilMemberId] = cmData for cmData in messages
          @councilMemberNames = messages.map (cmData, i, messages) ->
            cmData.firstName + ' ' + cmData.lastName
          @councilMembersStr = @councilMemberNames.join ', '

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

### postToEpiquery
Posts a payload to epiquery, then either executes the supplied callback on the results or resolves the promise with the results

      postToEpiquery: (uri, post, timeout, cb) ->
        new Promise (resolve,reject) =>
          qid = Math.random()
          msgArray = []
          epi.on 'endrowset', (msg) =>
            if qid is msg.queryId
              if cb?
                resolve()
              else
              resolve msgArray
          epi.on 'row', (msg) =>
            if qid is msg.queryId
              if cb?
                cb msg.columns
              else
                msgArray.push msg.columns
          epi.on 'error', (msg) =>
            reject new Error "postToEpiquery failed: #{msg.error}"
          epi.query 'glglive_o', uri, post, qid

### getMyProjects
Fetch of names of projects created in the last 90 days
where this user was either primary or delegate RM or recruiter

      getMyProjects: (currentuser) ->
        postToEpiquery = @postToEpiquery

#### buildHbIndex
Builds a hummingbird index with the list of projects returned by core-ajax call to epiquery

        buildHbIndex = (entity) =>
          (data) =>
            # build hb index from data
            @hb[entity].add data

        # lastUpdate must be seconds since epoch for sql server
        # chosen to round off lastUpdate to the nearest day-ish
        lastUpdate = Math.floor((new Date(new Date() - 1000*60*60*24*90)).getTime()/(24*60*60*1000))*24*60*60
        promisesArray = []
        timeout = 3*60*1000 # 3 min timeout
        post =
          lastUpdate: lastUpdate
          personId: @rmPersonId ? currentuser.detail.personId
        myConsultsUri = "nectar/glgliveMalory/getConsultsDelta.mustache"
        mySurveysUri = "nectar/glgliveMalory/getSurveyDelta.mustache"
        myMeetingsUri = "nectar/glgliveMalory/getEventsGroupsVisitsDelta.mustache"
        promisesArray.push postToEpiquery(myConsultsUri, post, timeout, buildHbIndex 'consults')
        promisesArray.push postToEpiquery(mySurveysUri, post, timeout, buildHbIndex 'surveys')
        promisesArray.push postToEpiquery(myMeetingsUri, post, timeout, buildHbIndex 'meetings')
        console.debug "Promise.all fired"
        Promise.all promisesArray
        .then undefined, (err) =>
          console.warn "Failed to build hb indexes: #{err}"
          Promise.reject()
        .then () =>
          for entity in Object.keys @hb
            console.debug "hummingbird #{entity}: #{Object.keys(@hb[entity].metaStore.root).length} items"
          @$.hbfetching.setAttribute 'hidden', true
          @$.inputwrapper.removeAttribute 'hidden' unless @hideUI
          @$.inputwrapper.focus() unless @hideUI
          @fire 'add-to-project-ready'

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
Does the attaching of council member(s) to the selected project

      selectProject: () ->
        selectedProject = @$.projects.value
        entity = @$.selectProjType.selectedItem.innerText

        track = (app=@appName, projId=selectedProject.id, cmIds=@cmIds, rmId=@rmPersonId, action='add') =>
          # tracking is intended to be fire-and-forget
          async = true
          url = "//services.glgresearch.com/trackingexpress/"
          url += "track/appName/#{app}/action/#{action}/personId/#{rmId}/consultationId/#{projId}/cmIds/[#{cmIds.split ','}]"
          request = new XMLHttpRequest
          request.withCredentials = true
          debugger
          #request.open 'GET', url, async
          #request.send()

        uri = ""
        switch entity
          when 'consults'
            console.info "consult selected #{selectedProject.name} (#{selectedProject.id})"
            postData =
              consultationId: selectedProject.id
              councilMembers: {id: id} for id in @cmIds.split ','
              userPersonId: @rmPersonId
            uri = "consultations/new/attachParticipants.mustache"
          when 'surveys'
            console.info "survey selected #{selectedProject.name} (#{selectedProject.id})"
            postData =
              surveyId: selectedProject.id
              personIds: @councilMembers[id].personId for id in @cmIds.split ','
              rmPersonId: @rmPersonId
            uri = "survey/qualtrics/attachCMToSurvey.mustache"
          when 'meetings' # aka, events, visits
            console.info "meeting selected #{selectedProject.name} (#{selectedProject.id})"
            postData =
              MeetingId: selectedProject.id
              PersonIds: {PersonId: @councilMembers[id].personId} for id in @cmIds.split ','
              LastUpdatedBy: @rmPersonId
            uri = "Event/attachCouncilMember.mustache"
          else
            console.error "unknown entity type: #{entity}"
            return
        debugger
        postToEpiquery uri, postData, 3*60*1000
        .then undefined, (err) ->
          console.error "** failed to attach to project: #{err}"
          @fire 'attachFailure',
            entity: entity
            projectId: selectedProject.id
            cmIds: @cmIds.split ','
          Promise.reject()
        .then (results) ->
          @fire 'attachSuccess',
            entity: entity
            projectId: selectedProject.id
            cmIds: @cmIds.split ','
          track() if entity is 'consults' # currently, we only track adds to consults

## Polymer Lifecycle

      created: ->
        @hideUI = false

      ready: ->
        @$.inputwrapper.setAttribute 'unresolved', ''
        @$.hbfetching.setAttribute 'hidden', 'true' if @hideUI
        @$.selectProjOwner.setAttribute 'hidden', true if @hideOwnerFilter or @hideUI
        @$.selectProjType.setAttribute 'hidden', true if @hideProjType or @hideUI
        @$.filterPipe.setAttribute 'hidden', true if @hideProjType or @hideOwnerFilter or @hideUI
        @$.experts.setAttribute 'hidden', true if @hideExperts or @hideUI
        @councilMembersStr = ""
        @councilMemberNames = []
        @councilMembers = {} # key=cmId

      attached: ->

      domReady: ->

      detached: ->

      publish:
        taskview:
          reflect: true
