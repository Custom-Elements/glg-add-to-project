# glg-add-to-project

    Polymer 'glg-add-to-project',

## targetChanged

If the person with that `cmId` is already attached to the project then
show an attached label.

      targetChanged: (oldValue, newValue) ->
        @attached = newValue.council_members[@cmId]

## Polymer Lifecycle

      created: ->

      ready: ->

      attached: ->
        @attached = false

      domReady: ->

      detached: ->
