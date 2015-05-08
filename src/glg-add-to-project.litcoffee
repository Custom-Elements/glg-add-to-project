# glg-add-to-project
A dialog to allow one or more CMs to be added to a consult,
survey, or various types of in-person meetings.

    hummingbird = require 'hummingbird'
    moment = require 'moment'
    hbOptions =
      scoreThreshold: 0.5
      secondarySortField: 'createDate'
      secondarySortOrder: 'desc'
      howMany: 10
    epiquery2 = require 'epiquery2'

    PolymerExpressions::formatDate = (d) ->
      moment(d).format('L')

    Polymer 'glg-add-to-project',

## Attributes

## Events

## Methods

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
            console.error msg
            reject new Error "postToEpiquery failed: #{msg.error}"
          @epi.query 'glglive_o', uri, post, qid

##### buildIndex
Builds a hummingbird index with the list of projects returned by call to epiquery

      buildIndex: (evt, user, source) ->
        # lastUpdate must be seconds since epoch for sql server
        # chosen to round off lastUpdate to the nearest day-ish
        timeout = 3*60*1000 # 3 min timeout
        post =
          userId: user.userId
          personId: user.personId
        @postToEpiquery("glgCurrentUser/getAddTargets.mustache", post, timeout)
          .then (data) =>
            data.forEach (doc) =>
              @localIndex.add doc
            @search()

#### search
Primary function for retrieving typeahead results from either hummingbird or nectar

      search: () ->
        @localIndex.search @query, (results) =>
          @$.matches.model = {matches: results}
        , hbOptions

#### selectProject
Does the attaching of council member(s) to the selected project

      selectTarget: () ->
        @target = @$.targets.value
        console.log @target
        @fire 'change', @target

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
        @localIndex = new hummingbird

      attached: ->

      domReady: ->

      detached: ->
