# glg-add-to-project
A dialog to allow one or more CMs to be added to a consult,
survey, meeting, or event.

    hummingbird = require 'hummingbird'
    hbOptions =
      scoreThreshold: 0.5
      secondarySortField: 'createDate'
      secondarySortOrder: 'desc'
    Polymer 'glg-add-to-project',

## Attributes
### cmids
The IDs of council members to be added to the selected project

### appName
The name to use to identify the application or feature used in ATC for tracking dashboard purposes

### rmPersonId
The person ID of the RM taking the ATC action on these experts on this selected project

## Change Handlers
### appNameChanged

    appNameChanged: ->
      #  @appName

### cmidsChanged

    cmidsChanged: ->
      #  @cmids

### rmPersonIdChanged

    rmPersonIdChanged: ->
      # @rmPersonId

### filtersChanged

    filtersChanged: (evt, detail, sender) ->
      # determine if we're changing the projOwner or projType
      #if detail.isSelected and @nectar? and @hb?
      #  @nectar.entities = "['#{detail.item.textContent}']" if detail.item.parentElement.id is 'selectProjType'
        @search()

### queryUpdated

    queryUpdated: (evt, detail, sender) ->
      @query = evt.detail.value
      @search()

## Events
### atp-started
fired when an expert is about to be added to a project

### atp-succeeded
fired after an expert was successfully added to a project

### atp-failed
fired after failing to add an expert to a project

## Methods
### buildHummingbirdIndex
Builds a hummingbird index with the list of projects returned by core-ajax call to epiquery

    buildHummingbirdIndex: (data) ->
      # build hb index from data
      #TODO: persist hummingbird index to local storage for faster subsequent loads
      @hb = new hummingbird()
      @hb.add project for project in data.detail.response
      @$.spinner.removeAttribute 'class'
      @$.spinner.setAttribute 'hidden', true
      @$.inputwrapper.removeAttribute 'class'
      @$.inputwrapper.focus()
      console.log "hummingbird ready: #{Object.keys(@hb.metaStore.root).length} projects"

### getMyProjects
Fetch of names of projects created in the last 90 days
where this user was either primary or delegate RM or recruiter

    getMyProjects: (currentuser) ->
      # lastUpdate must be seconds since epoch for sql server
      lastUpdate = Math.floor((new Date(new Date() - 1000*60*60*24*90)).getTime()/(60*1000))*60
      # changing the URL triggers core-ajax fetch
      @$.myprojects.url = "http://mepiquery.glgroup.com/cache10m/nectar/glgliveMalory/getConsultsDelta.mustache?lastUpdate=#{lastUpdate}&personId=#{@rmPersonId ? currentuser.detail.personId}"
      console.log "projHandler.url set: #{@$.myprojects.url}"

### displayResults

    displayResults: (target) ->
      (results) ->
        target.$.projectMatches.model = {matches: results}
        console.log "results processed: #{results.length}"

### displayNectarResults

    displayNectarResults: (evt) ->
      console.log "stop here"
      @displayResults(evt.target) evt.detail.results.matches

### search
Primary function for retrieving typeahead results from either hummingbird or nectar

    #TODO: enable one or more indexes
    #TODO: create multiple hummingbird indexes: consults, meetings, surveys
    search: () ->
      if @query? and @$.selectProjOwner?.selectedItem? and @$.selectProjType?.selectedItem?
        if @$.selectProjOwner.selectedItem.innerText is 'mine'
          if isNaN(@query)
            @hb.search @query, @displayResults(@), hbOptions
          else
            @hb.jump @query, @displayResults(@), hbOptions
        else
          if isNaN(@query)
            @$.nectar.query @query
          else
            @$.nectar.jump @query

### prettyDate
Human readable formatted date string

    prettyDate: (d) ->
      d.toLocaleDateString()

## Polymer Lifecycle

    created: ->

    ready: ->
      @$.inputwrapper.setAttribute 'unresolved', ''
      console.log "cmids: #{@cmids}"
      console.log "appName: #{@appName}"
      console.log "rmPersonId: #{@rmPersonId}"

    attached: ->

    domReady: ->

    detached: ->

    publish:
      taskview:
        reflect: true
