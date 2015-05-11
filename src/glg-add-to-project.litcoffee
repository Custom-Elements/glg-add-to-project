# glg-add-to-project

    Polymer 'glg-add-to-project',

## targetChanged

If the person with that `cmId` is already attached to the project then
show an attached label.

      targetChanged: (oldValue, newValue) ->
        @attached = newValue.council_members[@cmId]

## addPerson

Add the person specified by `cmId` to the target, if any. If no target, do nothing.

      addPerson: (withPriority=false)->
        return if not @target

What type of project are we adding to? What is its `id`? Once we have that,
figure out where we're posting the data and what the params should be.

        [projectType, id] = @target.id.split ':'
        console.log "glgatp: #{projectType}:#{id}"
        switch projectType
          when 'consultation'
            console.debug "glg-atp: consult #{id}"
            postData =
              consultationId: id
              userPersonId: @currentuser.personId
              councilMembers: [{id: @cmId}]
              withPriority: withPriority
            uri = "consultations/new/attachParticipants2.mustache"
          when 'survey2'
            console.debug "glg-atp: survey #{id}"
            postData =
              SurveyId: id
              personIds: [@personId]
              rmPersonId: @currentuser.personId
            uri = "survey/attachCMToSurvey20.mustache"
          when 'survey3'
            console.debug "glg-atp: survey #{id}"
            postData =
              surveyId: id
              personIds: [@personId]
              rmPersonId: @currentuser.personId
            uri = "survey/qualtrics/attachCMToSurvey.mustache"
          when 'meetings' # aka, events, visits
            console.debug "glg-atp: meeting #{id}"
            postData =
              MeetingId: id
              PersonIds: [{PersonId: @personId}]
              LastUpdatedBy: @currentuser.personId
            uri = "Event/attachCouncilMember.mustache"
          else
            console.error "glg-atp: unknown entity type: #{projectType}"
            return
        console.log uri, postData
        # @postToEpiquery uri, postData, 3*60*1000
        # .then undefined, (err) =>
        #   @fire 'atp-failed',
        #     entity: entity
        #     projectId: selectedProject.id
        #     cmIds: @cmIds.split ','
        #     error: err
        #   Promise.reject()
        # .then (messages) =>
        #   @fire 'atp-succeeded',
        #     entity: entity
        #     projectId: selectedProject.id
        #     cmIds: @cmIds.split ','
        #   track() if entity is 'consults' # currently, we only track adds to consults


## Polymer Lifecycle

      created: ->

      ready: ->

      attached: ->
        @attached = false

      domReady: ->

      detached: ->
