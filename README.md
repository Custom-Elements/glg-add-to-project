# glg-add-to-project

Polymer component that exposes a service end-point for adding one or more CMs to
a single consult, survey, meeting, or event as selected by the user via nectar/hummingbird typeahead.
It relies on glue code to grab personId of current user, project ID, and
CMID, then assigns the values to this element's published attributes.

Currently, the primary use case is the ATC button on the new Advisor's page.

## Developing

`git clone git@github.com/Custom-Elements/glg-add-to-project.git`

`npm install`

## Running demo

`npm test`

## To Do
* Use dbSockets to add Mosaic Lists as an option under "project type" - which
  should probably be renamed now. Stakeholder: Ariela Rosenberg
* Persist HB indexes with lastUpdate datetime to local storage for faster subsequent loading
* Get designer feedback on GUI style
* Dump ui-toolkit in favor of slimmer, barebones necessities
