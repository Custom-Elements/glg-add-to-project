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
    epiUrlTemplate = "glgresearch.com/epistream-consultations-clustered/sockjs/websocket"
    #episervers = ("wss://#{region}.#{epiUrlTemplate}" for region in ['services','asia','east','europe','west'])
    episervers = "wss://services.#{epiUrlTemplate}"
    epi = new epiquery2.EpiClient episervers

    Polymer 'glg-add-to-project',

### Attributes
#### cmIds
The IDs of council members to be added to the selected project

#### appName
The name to use to identify the application or feature used in ATC for tracking dashboard purposes

#### hideUI
Toggles whether to display a UI at all.  If not included, it is displayed.
If included as an attribute on the element, the component is available as an invisible service.

#### hideOwnerFilter
Toggles whether to display the project owner filter in the UI.  If not included, it is displayed.

#### hideProjType
Toggles whether to display the project type filter in the UI.  If not included, it is displayed.

#### hideExperts
Toggles whether to display the Council Members to-be-added in the UI.  If not included, it is displayed.

#### rmPersonId
The person ID of the RM taking the ATC action on these experts on this selected project

### Globals
#### hb
Collection of hummingbird indexes, one per type of project entity

      hb:
        consults: new hummingbird
        meetings: new hummingbird
        surveys: new hummingbird


### Attribute Change Handlers
#### cmIdsChanged

      cmIdsChanged: (oldVal, newVal) ->
        uri = "councilMember/getCouncilMemberBrief.mustache"
        post =
          councilMemberIds: newVal.split ','
        @postToEpiquery uri, post, 15*1000
        .then undefined, (err) =>
          console.error "cmIdsChanged but failed to fetch details: #{err}"
          Promise.reject()
        .then (messages) =>
          @councilMembers[cmData.councilMemberId] = cmData for cmData in messages
          @councilMemberNames = messages.map (cmData, i, messages) ->
            cmData.firstName + ' ' + cmData.lastName
          @councilMembersStr = @councilMemberNames.join ', '

### Events
#### atp-ready
fired as soon as hummingbird indexes are built and available for searching

#### atp-started
fired when an expert is about to be added to a project

#### atp-succeeded
fired after an expert was successfully added to a project

#### atp-failed
fired after failing to add an expert to a project

### Methods
#### filtersUpdated
Executes a new search when a different type of project is selected

      filtersUpdated: (evt, detail, sender) ->
        # don't search until we're ready
        if detail.isSelected and @$.nectar? and @hb?
          @$.nectar.entities = detail.item.textContent if detail.item.parentElement.id is 'selectProjType'
          @search()

#### queryUpdated
Executes a new search with the new query

      queryUpdated: (evt, detail, sender) ->
        @query = detail.value
        @search()

#### postToEpiquery
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

#### getMyProjects
Fetch of names of projects created in the last 90 days
where this user was either primary or delegate RM or recruiter

      getMyProjects: (currentuser) ->
        @rmPersonId = @rmPersonId ? currentuser?.detail?.personId

##### buildHbIndex
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
          personId: @rmPersonId ? currentuser?.detail?.personId
        myConsultsUri = "nectar/glgliveMalory/getConsultsDelta.mustache"
        mySurveysUri = "nectar/glgliveMalory/getSurveyDelta.mustache"
        myMeetingsUri = "nectar/glgliveMalory/getEventsGroupsVisitsDelta.mustache"
        promisesArray.push @postToEpiquery(myConsultsUri, post, timeout, buildHbIndex 'consults')
        promisesArray.push @postToEpiquery(mySurveysUri, post, timeout, buildHbIndex 'surveys')
        promisesArray.push @postToEpiquery(myMeetingsUri, post, timeout, buildHbIndex 'meetings')
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
          console.log "fired 'atp-ready'"

#### displayResults
Used by displayNectarResults and directly as a callback passed to hummingbird index queries.

      displayResults: (target) ->
        (results) ->
          target.$.projectMatches.model = {matches: results}

#### displayNectarResults
Used to display nectar results and assumes that the results are interleaved, not grouped by entity.

      displayNectarResults: (evt, detail, sender) ->
        @displayResults(evt.target) detail.results.matches

#### search
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

#### selectProject
Does the attaching of council member(s) to the selected project

      selectProject: () ->
        selectedProject = @$.projects.value
        entity = @$.selectProjType.selectedItem.innerText
        @fire 'atp-started',
          entity: entity
          projectId: selectedProject.id
          cmIds: @cmIds.split ','
        console.log "fired 'atp-started'"

        track = (app=@appName, projId=selectedProject.id, cmIds=@cmIds, rmId=@rmPersonId, action='add') =>
          # tracking is intended to be fire-and-forget
          async = true
          url = "//services.glgresearch.com/trackingexpress/"
          url += "track/appName/#{app}/action/#{action}/personId/#{rmId}/consultationId/#{projId}/cmIds/[#{cmIds.split ','}]"
          request = new XMLHttpRequest
          request.withCredentials = true
          request.open 'GET', url, async
          request.send()

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
            console.info "survey selected name: #{selectedProject.name}, id: #{selectedProject.id}, type: #{selectedProject.type}"
            if selectedProject.type is 'Surveys 3.0'
              postData =
                surveyId: selectedProject.id
                personIds: @councilMembers[id].personId for id in @cmIds.split ','
                rmPersonId: @rmPersonId
              uri = "survey/qualtrics/attachCMToSurvey.mustache"
            else if selectedProject.type is 'Surveys 2.0'
              postData =
                SurveyId: selectedProject.id
                personIds: @councilMembers[id].personId for id in @cmIds.split ','
                rmPersonId: @rmPersonId
              uri = "survey/attachCMToSurvey20.mustache"
            else
              console.error "unknown survey type: #{selectedProject.type}"
              return
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
        @postToEpiquery uri, postData, 3*60*1000
        .then undefined, (err) =>
          @fire 'atp-failed',
            entity: entity
            projectId: selectedProject.id
            cmIds: @cmIds.split ','
            error: err
          console.log "fired 'atp-failed': #{err}"
          Promise.reject()
        .then (messages) =>
          @fire 'atp-succeeded',
            entity: entity
            projectId: selectedProject.id
            cmIds: @cmIds.split ','
          console.log "fired 'atp-succeeded'"
          track() if entity is 'consults' # currently, we only track adds to consults

### Polymer Lifecycle

      created: ->
        @hideUI = false

      ready: ->
        @$.inputwrapper.setAttribute 'unresolved', ''
        @$.hbfetching.setAttribute 'hidden', 'true' if @hideUI
        @$.selectProjOwner.setAttribute 'hidden', true if @hideOwnerFilter or @hideUI
        @$.selectProjType.setAttribute 'hidden', true if @hideProjType or @hideUI
        @$.filterPipe.setAttribute 'hidden', true if @hideProjType or @hideOwnerFilter or @hideUI
        @$.experts.setAttribute 'hidden', true if @hideExperts or @hideUI
        @councilMemberNames = []
        @councilMembers = {} # key=cmId
        @councilMembersStr = "none chosen"

      attached: ->

      domReady: ->

      detached: ->
