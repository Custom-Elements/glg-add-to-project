# glg-add-to-project

## Libraries

    epiquery2 = require 'epiquery2'

## "Constants"

    epiStreamUrl = "wss://services.glgresearch.com/epistream-ldap/sockjs/websocket"

## `glg-add-to-project` Polymer declaration

    Polymer 'glg-add-to-project',

### targetChanged

If the person with that `cmId` is already attached to the project then
show an attached label.

      targetChanged: (oldValue, newValue) ->
        @cmAttached = newValue.council_members[@cmId]

### epiquery

We're going to get passed messages as results come in from, perhaps, multiple
calls. Let's set up some handlers for that.

Central to this is the `qidMap`. It maintains a map of queryIds (random number)
to an object that looks like this:

  resolve: Promise.resolve
  reject: Promise.reject
  msgArray: []

As epi messages come in we append to msgArray. Once the rowset is complete we
resolve the promise and delete the mapping. On error, we reject with the error
from epi.

      setupEpi: ->
        @epi = new epiquery2.EpiClient epiStreamUrl
        @qidMap = {}
        @epi.on 'endrowset', (msg) =>
          mapping = @qidMap[msg.queryId]
          if not mapping
            console.warning 'Received epi message with no associated qid:', msg
            return
          mapping.resolve(mapping.msgArray)
          @qidMap[msg.queryId] = null
        @epi.on 'row', (msg) =>
          mapping = @qidMap[msg.queryId]
          if not mapping
            console.warning 'Received epi message with no associated qid:', msg
            return
          mapping.msgArray.push(msg.columns)
        @epi.on 'error', (msg) =>
          mapping = @qidMap[msg.queryId]
          if not mapping
            console.warning 'Received epi message with no associated qid:', msg
            return
          mapping.reject new Error msg.error

Make the actual call to epi and set up the `qidMap` structure.

      postToEpiquery: (templatePath, body) ->
        new Promise (resolve, reject) =>
          qid = Math.random()
          @qidMap[qid] =
            resolve: resolve
            reject: reject
            msgArray: []
          @epi.query 'glglive_o', templatePath, body, qid


### addPerson

Add the person specified by `cmId` to the target, if any. If no target, do nothing.

      addPerson: ->
        return if not @target

What type of project are we adding to? What is its `id`? Once we have that,
figure out where we're posting the data and what the params should be.

        [projectType, id] = @target.id.split ':'
        switch projectType
          when 'consultation'
            console.debug "glg-atp: consult #{id}"
            body =
              consultationId: id
              councilMembers: [{id: @cmId}]
              userPersonId: @currentuser.personId
              # TODO: Parameterize?
              source: 'glg-add-to-project'
            templatePath = "consultations/new/attachParticipants2.mustache"
          when 'surveys'
            console.debug "glg-atp: survey #{id}"
            # TODO: Differentiate surveys?
            # if selectedProject.type is 'Surveys 3.0'
            #   body =
            #     surveyId: id
            #     # TODO: Need personId instead of cmId here?
            #     personIds: @councilMembers[id].personId for id in @cmIds.split ','
            #     rmPersonId: @currentuser.personId
            #   templatePath = "survey/qualtrics/attachCMToSurvey.mustache"
            # else if selectedProject.type is 'Surveys 2.0'
            #   body =
            #     SurveyId: id
            #     personIds: @councilMembers[id].personId for id in @cmIds.split ','
            #     rmPersonId: @currentuser.personId
            #   templatePath = "survey/attachCMToSurvey20.mustache"
            # else
            #   console.error "glg-atp: unknown survey type: #{selectedProject.type}"
            #   return
          when 'meetings' # aka, events, visits
            console.debug "glg-atp: meeting #{id}"
            body =
              MeetingId: id
              # PersonIds: {PersonId: @councilMembers[id].personId} for id in @cmIds.split ','
              LastUpdatedBy: @currentuser.personId
            templatePath = "Event/attachCouncilMember.mustache"
          else
            console.error "glg-atp: unknown entity type: #{projectType}"
            return
        @working = true
        @postToEpiquery templatePath, body
          .then =>
            @cmAttached = true
          , (err) =>
            console.error "Error:#{err}, Path:#{templatePath}, Body:#{body}"
          .then =>
            @working = false


### Polymer Lifecycle

      created: ->

      ready: ->
        @working = true
        @setupEpi()

      attached: ->
        @cmAttached = false

      domReady: ->

      detached: ->
