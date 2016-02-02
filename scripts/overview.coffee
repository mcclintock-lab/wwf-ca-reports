ReportTab = require 'reportTab'
templates = require '../templates/templates.js'



class OverviewTab extends ReportTab
  name: 'Cumulative Impact'
  className: 'overview'
  timeout: 120000
  template: templates.overview
  dependencies: ['CumulativeImpacts']

  render: () ->
    isCollection = @model.isCollection()
    totals = @recordSet('CumulativeImpacts', 'CI_Totals').toArray()
    console.log(".....", totals)

    cumulativeImpact = @recordSet('CumulativeImpacts', 'CumulativeImpact').toArray()
    console.log(cumulativeImpact)
    # setup context object with data and render the template from it
    context =
      sketch: @model.forTemplate()
      sketchClass: @sketchClass.forTemplate()
      attributes: @model.getAttributes()
      admin: @project.isAdmin window.user
      cumulativeImpact: totals

    @$el.html @template.render(context, templates)

module.exports = OverviewTab