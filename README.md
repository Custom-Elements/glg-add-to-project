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
* Analyze probability of ATC by unassociated RM for the last 12 months.
* Analyze same distributions/probabilities for surveys, meetings, and events.

### Implementation
* Use glg-current-user to know who the user is.
* Use either hummingbird or glg-nectar to select project via typeahead/autocomplete.
* Use core-ajax to add CM to project via epiquery.
* Use core-ajax within the callback of first core-ajax call to submit to the tracking service.

