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
        if newValue
          @isConsultation = newValue?.id?.startsWith 'consultation'
          @cmAttached = newValue?.council_members[@cmId]
        else
          @isConsultation = false
          @cmAttached = false

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
And, yuck, the method dispatch in this with those two params just got gross. I should
fix this eventually.

      addPerson: (withPriority=false, toReferralList=false)->
        return if not @target

What type of project are we adding to? What is its `id`? Once we have that,
figure out where we're posting the data and what the params should be.

        [projectType, id] = @target.id.split ':'
        switch projectType
          when 'consultation'
            console.debug "glg-atp: consult #{id}"
            if not toReferralList
              body =
                consultationId: id
                councilMembers: [{id: @cmId}]
                userPersonId: @currentuser.personId
                withPriority: withPriority
                # TODO: Parameterize?
                source: 'glg-add-to-project'
              templatePath = 'consultations/new/attachParticipants2.mustache'
            else
              body =
                consultationId: id
                councilMemberId: @cmId
                user: @currentuser
              templatePath = 'consultations/new/addCouncilMemberToReferralList.mustache'
          when 'survey2'
            console.debug "glg-atp: survey #{id}"
            body =
              SurveyId: id
              personIds: [@personId]
              rmPersonId: @currentuser.personId
            templatePath = 'survey/attachCMToSurvey20.mustache'
          when 'survey3'
            console.debug "glg-atp: survey #{id}"
            body =
              surveyId: id
              personIds: [@personId]
              rmPersonId: @currentuser.personId
            templatePath = 'survey/qualtrics/attachCMToSurvey.mustache'
          when 'meetings' # aka, events, visits
            console.debug "glg-atp: meeting #{id}"
            body =
              MeetingId: id
              PersonIds: [{PersonId: @personId}]
              LastUpdatedBy: @currentuser.personId
            templatePath = 'Event/attachCouncilMember.mustache'
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

### Button Handlers

Bog-standard "add this person" click.

      onAddClicked: (e, detail, sender) ->
        @addPerson()

Show the dropdown for consultation targets. Grants adding with priority
and adding to referral list.

      onDropdownClicked: (e, detail, sender) ->
        @hideDropdown = !@hideDropdown

      onAddWithPriorityClicked: (e, detail, sender) ->
        @hideDropdown = true
        @addPerson(true)

      onAddToReferralListClicked: (e, detail, sender) ->
        @hideDropdown = true
        @addPerson(false, true)

If the user clicks somewhere else we should hide our dropdown, if showing.

      onDocumentClicked: (e, detail, sender) ->
        @hideDropdown = true if e.target isnt @

### Polymer Lifecycle

      created: ->

      ready: ->
        @working = false
        @hideDropdown = true
        @setupEpi()

      attached: ->
        @cmAttached = false

The value of "@" inside onDocumentClicked with a fat arrow when attached from the
ready method was a bare object, even though the value of "@" inside the ready method
is correct. *Probably* something to do with how Polymer clones this prototype object
on instantiation but I didn't dig.

        @boundDocClick = @onDocumentClicked.bind(@)
        document.addEventListener 'click', @boundDocClick

      domReady: ->

      detached: ->
        document.removeEventListener 'click', @boundDocClick
