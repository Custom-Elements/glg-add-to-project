# glg-add-to-project

Polymer component for adding one or more CMs to a single consult, survey, meeting, or event as selected by the user
via nectar/hummingbird typeahead. It relies on glue code to supply the council member ID(s) via this element's published attribute.

The current use case is the *Add To Consultation* button on the new [Advisor
Details](https://services.glgresearch.com/advisors/#/cm/3938) page.

## Developing

`git clone git@github.com/Custom-Elements/glg-add-to-project.git`

`npm install`

## Running demo

Begin by executing `npm test` from the root of the repo

Then,
* open Chrome to `http://localhost:1000/demo.html`

Alternatively,
* edit your `/etc/hosts` to add an entry like `127.0.0.1 consultations.glgroup.com`
  * This ensures that [glg-currrent-user](https://github.com/Custom-Elements/glg-current-user) can read your cookies.
* then open Chrome to `http://consultations.glgroup.com:1000/demo.html`

```
    BEWARE:

    As is, if you use the demo to attach a CM to a project, it will,
    no-foolin', attach real CMs to real projects in
    the real production database.  Clean-up after yourself!

    i.e., unattach said CMs from said project via the web UI.
```

## To Do
* Use dbSockets to add Mosaic Lists as an option under "project type" - which
  should probably be renamed now. Stakeholder: Ariela Rosenberg
* Persist HB indexes with lastUpdate datetime to local storage for faster subsequent loading
* Get designer feedback on GUI style
* Dump ui-toolkit in favor of slimmer, barebones necessities


## Attributes
##### cmIds
The IDs of council members to be added to the selected project.
Expected to be a comma separated string of ints.

##### appName
The name to use to identify the application or feature used in ATC for tracking dashboard purposes

##### hideUI
Toggles whether to display a UI at all.  If not included, it is displayed.
If included as an attribute on the element, the component is available as an invisible service.

##### hideOwnerFilter
Toggles whether to display the project owner filter in the UI.  If not included, it is displayed.

##### hideProjType
Toggles whether to display the project type filter in the UI.  If not included, it is displayed.

##### hideExperts
Toggles whether to display the Council Members to-be-added in the UI.  If not included, it is displayed.

##### rmPersonId
The person ID of the RM taking the ATC action on these experts on this selected project

## Events
##### atp-ready
fired as soon as hummingbird indexes are built and available for searching

##### atp-started
fired when an expert is about to be added to a project

##### atp-succeeded
fired after an expert was successfully added to a project

##### atp-failed
fired after failing to add an expert to a project

