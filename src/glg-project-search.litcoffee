# glg-project-search
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
    timeout = 1*60*1000

    PolymerExpressions::formatDate = (d) ->
      moment(d).format('L')

    Polymer 'glg-project-search',

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
        post =
          userId: user.userId
          personId: user.personId
        @postToEpiquery("glgCurrentUser/getAddTargets.mustache", post, timeout)
          .then (data) =>
            data.forEach (doc) =>
              console.log doc
              @localIndex.add doc
            @search()

#### search
Primary function for retrieving typeahead results from either hummingbird or nectar

      search: () ->
        @localIndex.search @query, (results) =>
          @$.matches.model = {matches: results}
        , hbOptions

#### getAttachedCouncilMembers
Load up all attached council members on to the selected target.

      getAttachedCouncilMembers: () ->
        if @target
          flavor = @target.id.split(':')[0]
          switch flavor
            when 'consultation'
              url = "consultations/getConsultationParticipantsCMIds.mustache"
              parameters =
                consultationId: @target.sourceid
            when 'meeting'
              url = "Event/getCouncilMembers.mustache"
              parameters =
                meetingId: @target.sourceid
            when 'survey2'
              url = "survey/getSurvey2Participants.mustache"
              parameters =
                surveyId: @target.sourceid
            when 'survey3'
              url = "survey/getQualtricsParticipants.mustache"
              parameters =
                surveyId: @target.sourceid
            when 'list'
              url = "lists/getPeopleOnList.mustache"
              parameters =
                listId: @target.sourceid

          @postToEpiquery(url, parameters, timeout)
            .then (data) =>
              @target.council_members = {}
              data.forEach (doc) =>
                @target.council_members[doc.COUNCIL_MEMBER_ID] = true
                console.log doc
              @fire 'change', @target

#### selectProject
When a project is selected, bind it to an attribute. Then ask epiquery for the
list of existing attached folks.

      selectTarget: () ->
        @target = @$.targets.value
        @getAttachedCouncilMembers @target

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