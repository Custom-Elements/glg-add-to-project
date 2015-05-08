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

    Polymer 'glg-add-to-project',

## Attributes
#### targetType
All kinds of targets can take an attach. Set the value here to correspond
to the visual option to select the target type. Things like consults, lists ...

      targetTypeChanged: ->
        @shadowRoot.querySelector('select').value = @targetType

## Globals
#### hb
Collection of hummingbird indexes, one per type of project entity

      hb:
        consults: new hummingbird
        meetings: new hummingbird
        surveys: new hummingbird

#### epi
Epiquery2 client for fetching remote data over websockets

## Events
#### target-selected
Fired when you have picked a container target to receive CMs.

## Methods
#### targetTypeSelected
Hook up the DOM event to an attribute.

      targetTypeSelected: (evt, target, element) ->
        @targetType = element.value
        @search()

#### queryUpdated
Executes a new search with the new query

      queryUpdated: (evt, detail, sender) ->
        @query = detail.value
        @search()

#### postToEpiquery
Posts a payload to epiquery, then either executes the supplied callback on the results or resolves the promise with the results

      postToEpiquery: (uri, post, timeout) ->
        new Promise (resolve,reject) =>
          qid = Math.random()
          msgArray = []
          @epi.on 'endrowset', (msg) =>
            if qid is msg.queryId
              resolve msgArray
          @epi.on 'row', (msg) =>
            if qid is msg.queryId
              if cb?
                cb msg.columns
              else
                msgArray.push msg.columns
          @epi.on 'error', (msg) =>
            reject new Error "postToEpiquery failed: #{msg.error}"
          @epi.query 'glglive_o', uri, post, qid

##### buildIndex
Builds a hummingbird index with the list of projects returned by call to epiquery

      buildIndex: (evt, user, source) ->
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
          personId: user.personId
        @postToEpiquery("nectar/glgliveMalory/getConsultsDelta.mustache", post, timeout)
          .then (data) =>
            data.forEach (doc) =>
              @hb.consults.add doc
            @search()
        @postToEpiquery("nectar/glgliveMalory/getSurveyDelta.mustache", post, timeout)
          .then (data) =>
            data.forEach (doc) =>
              @hb.surveys.add doc
            @search()
        @postToEpiquery("nectar/glgliveMalory/getEventsGroupsVisitsDelta.mustache", post, timeout)
          .then (data) =>
            data.forEach (doc) =>
              @hb.meetings.add doc
            @search()

#### search
Primary function for retrieving typeahead results from either hummingbird or nectar

      search: () ->
        @hb[@targetType].search @query, (results) =>
          @$.projectMatches.model = {matches: results}
        , hbOptions

#### selectProject
Does the attaching of council member(s) to the selected project

      selectProject: () ->
        debugger
        selectedProject = @$.projects.value
        entity = @$.selectProjType.selectedItem.textContent # avoid .innerText
        @fire 'atp-started',
          entity: entity
          projectId: selectedProject.id
          cmIds: @cmIds.split ','

        track = (app=@appName, projId=selectedProject.id, cmIds=@cmIds, rmId=@rmPersonId, action='add') =>
          # tracking is intended to be fire-and-forget
          async = true
          app ?= 'unknown'
          url = "#{@trackUrl}track/appName/#{app}/action/#{action}/personId/#{rmId}/consultationId/#{projId}/cmIds/[#{cmIds.split ','}]"
          request = new XMLHttpRequest
          request.withCredentials = true
          request.open 'GET', url, async
          request.send()

        uri = ""
        switch entity
          when 'consults'
            console.debug "glg-atp: consult selected #{selectedProject.name} (#{selectedProject.id})"
            postData =
              consultationId: selectedProject.id
              councilMembers: {id: id} for id in @cmIds.split ','
              userPersonId: @rmPersonId
            uri = "consultations/new/attachParticipants.mustache"
          when 'surveys'
            console.debug "glg-atp: survey selected name: #{selectedProject.name}, id: #{selectedProject.id}, type: #{selectedProject.type}"
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
              console.error "glg-atp: unknown survey type: #{selectedProject.type}"
              return
          when 'meetings' # aka, events, visits
            console.debug "glg-atp: meeting selected #{selectedProject.name} (#{selectedProject.id})"
            postData =
              MeetingId: selectedProject.id
              PersonIds: {PersonId: @councilMembers[id].personId} for id in @cmIds.split ','
              LastUpdatedBy: @rmPersonId
            uri = "Event/attachCouncilMember.mustache"
          else
            console.error "glg-atp: unknown entity type: #{entity}"
            return
        @postToEpiquery uri, postData, 3*60*1000
        .then undefined, (err) =>
          @fire 'atp-failed',
            entity: entity
            projectId: selectedProject.id
            cmIds: @cmIds.split ','
            error: err
          Promise.reject()
        .then (messages) =>
          @fire 'atp-succeeded',
            entity: entity
            projectId: selectedProject.id
            cmIds: @cmIds.split ','
          track() if entity is 'consults' # currently, we only track adds to consults

## Polymer Lifecycle

      created: ->
        @epiStreamUrl = "wss://services.glgresearch.com/epistream-ldap/sockjs/websocket"
        @nectarUrl = "wss://nectar.glgroup.com/ws"

      ready: ->
        @epi = new epiquery2.EpiClient @epiStreamUrl

      attached: ->
        @targetType = "consults"

      domReady: ->

      detached: ->
