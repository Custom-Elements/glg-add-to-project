# glg-add-to-project

    Polymer 'glg-add-to-project',

## targetChanged

If the person with that `cmId` is already attached to the project then
show an attached label.

      targetChanged: (oldValue, newValue) ->
        @attached = newValue.council_members[@cmId]

## addPerson

Add the person specified by `cmId` to the target, if any. If no target, do nothing.

      addPerson: ->
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
              councilMembers: @cmId
              userPersonId: @currentuser.personId
            uri = "consultations/new/attachParticipants.mustache"
          when 'surveys'
            console.debug "glg-atp: survey #{id}"
            # TODO: Differentiate surveys?
            # if selectedProject.type is 'Surveys 3.0'
            #   postData =
            #     surveyId: id
            #     # TODO: Need personId instead of cmId here?
            #     personIds: @councilMembers[id].personId for id in @cmIds.split ','
            #     rmPersonId: @currentuser.personId
            #   uri = "survey/qualtrics/attachCMToSurvey.mustache"
            # else if selectedProject.type is 'Surveys 2.0'
            #   postData =
            #     SurveyId: id
            #     personIds: @councilMembers[id].personId for id in @cmIds.split ','
            #     rmPersonId: @currentuser.personId
            #   uri = "survey/attachCMToSurvey20.mustache"
            # else
            #   console.error "glg-atp: unknown survey type: #{selectedProject.type}"
            #   return
          when 'meetings' # aka, events, visits
            console.debug "glg-atp: meeting #{id}"
            postData =
              MeetingId: id
              # PersonIds: {PersonId: @councilMembers[id].personId} for id in @cmIds.split ','
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
