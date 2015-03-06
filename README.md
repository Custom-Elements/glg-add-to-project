# glg-add-to-project - **WORK IN PROGRESS - NOT READY FOR USE**

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

## THE PLAN

### Analysis
* Analyze distribution of consult age at time of ATC for the last 12 months.
  * sharp drop off after 3 months
* Analyze probability of ATC by unassociated RM for the last 12 months.
  * roughly 65% of ATC done by primary/delegate, 35% are by another RM.
* Analyze same distributions/probabilities for surveys, meetings, and events.
  * TBD

### Implementation
* Use glg-current-user to know who the user is.
  * done
* Use epiclient to fetch current-user's consults, surveys, & meetings for last 3 months via epiquery.
  * http://mepiquery.glgroup.com/nectar/glgliveMalory/getConsultsDelta.mustache?lastUpdate=####&personId=####
  * done
* Use hummingbird to build index and display projects via typeahead.
  * done
* Use glg-nectar to display projects from all users all time when user wants.
  * done
* Use epiclient to add CM to project via epiquery.
  * in process
* Use XMLHTTPRequest within the callback of first core-ajax call to submit to the tracking service.
  * in process
* Use dbSockets to add Mosaic Lists as an option under "project type" - which
  should probably be renamed now. Stakeholder: Ariela Rosenberg

### Polish
* Persist HB indexes with lastUpdate datetime to local storage for faster subsequent loading
* Get designer feedback on GUI style
* Dump ui-toolkit in favor of slimmer, barebones necessities
* Push ui-typeahead changes - DONE
* Deploy nectar config changes for secondary sorting
