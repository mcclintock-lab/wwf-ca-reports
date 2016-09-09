ReportTab = require 'reportTab'
templates = require '../templates/templates.js'



class OverviewTab extends ReportTab
  name: 'Cumulative Impact'
  className: 'overview'
  timeout: 120000
  template: templates.overview
  dependencies: [
    'CumulativeImpacts'
    'CumulativeImpactsPerHabitat'
  ]

  render: () ->
    d3IsPresent = window.d3

    isCollection = @model.isCollection()
    totals = @recordSet('CumulativeImpacts', 'CI_Totals').toArray()

    hasModified = false

    stressors_per_habitat = @recordSet('CumulativeImpactsPerHabitat', 'CumulativeImpact').toArray()
    
    habitatsForStressors = [{VAL:"all", DISPLAY:"All Habitats", sel:'selected'}, {VAL:"bh", DISPLAY:"Benthic Habitats", sel:''},
                            {VAL:"dp", DISPLAY:"Deep Pelagic", sel:''},{VAL:"eg", DISPLAY:"Eelgrass",sel:''},
                            {VAL:"kp", DISPLAY:"Kelp", sel:''}, {VAL:"sp", DISPLAY:"Shallow Pelagic",sel:''},
                            {VAL:"sr", DISPLAY:"Sponge Reef",sel:''}]


    stressors = _.filter stressors_per_habitat, (r) -> r.SC_ID == 'all'
    ci_totals = {NAME:"Total", PERC_TOT:100.0, PERC_MOD:'--',CUM_IMPACT:0.0}

    for s in stressors_per_habitat
      s.CUM_IMPACT = Number(s.CUM_IMPACT).toFixed(2)
      try
        if !isNaN(s.CUM_IMPACT)
          ci_totals.CUM_IMPACT = Number(ci_totals.CUM_IMPACT) + Number(s.CUM_IMPACT)
      
      catch e
        #skip any non-numbers
      
      
      if s.PERC_MOD != '100'
        s.MOD_VAL_DOWN = 1/s.PERC_MOD
        s.MOD_VAL_UP = -1*s.PERC_MOD
        s.IS_MOD = true
        hasModified = true
      else
        s.MOD_VAL_DOWN = -1*s.PERC_MOD
        s.MOD_VAL_UP = s.PERC_MOD
        s.IS_MOD = false

      s.PERC_MOD = Number(s.PERC_MOD).toFixed(0)
      s.PERC_TOT = Number(s.PERC_TOT).toFixed(1)

    #stressors.push(ci_totals)

    if !hasModified
      totals = _.filter totals, (r) -> r.VERSION != 'Modified Scores'

    # setup context object with data and render the template from it
    context =
      sketch: @model.forTemplate()
      sketchClass: @sketchClass.forTemplate()
      attributes: @model.getAttributes()
      admin: @project.isAdmin window.user
      d3IsPresent: d3IsPresent
      totals: totals
      stressors: stressors
      hasModified: hasModified
      habitatsForStressors: habitatsForStressors

    @$el.html @template.render(context, templates)


    #make sure this comes before paging, otherwise pages won't be there  
    
    
    @$('.chosen-habs').chosen({disable_search_threshold: 10})
    @$('.chosen-habs').change () =>
      _.defer @renderStressorsPerHabitat(stressors_per_habitat)
    @$('.show_nonzero').change () =>
      _.defer @doShowNonzeroClick(stressors_per_habitat)
    
    @setupStressorSorting(stressors_per_habitat)
    #@enableTablePaging()

  renderStressorsPerHabitat: (stressors_per_habitat) => 

    tbodyName = '.stressor_values'
    tableName = '.stressor_table'
    stressorFunction = ["NAME", "PERC_MOD", "PERC_TOT"]
    @renderSort('NAME', tableName, undefined, "NAME", tbodyName, false, stressorFunction, true, stressors_per_habitat)

  doShowNonzeroClick: (stressors_per_habitat) =>

    tbodyName = '.stressor_values'
    tableName = '.stressor_table'
    stressorFunction = ["NAME","PERC_MOD", "PERC_TOT"]
    @renderSort('NAME', tableName, undefined, "NAME", tbodyName, false, stressorFunction, true, stressors_per_habitat)

  setupStressorSorting: (all_stressors_per_habitat) =>
    tbodyName = '.stressor_values'
    tableName = '.stressor_table'
    stressorFunction = ["NAME", "PERC_MOD", "PERC_TOT"]
    
    @$('.stressor_name').click (event) =>
      @renderSort('stressor_name', tableName, event, "NAME", tbodyName, false, stressorFunction, false, all_stressors_per_habitat)

    @$('.stressor_perc_adj').click (event) =>
      @renderSort('stressor_perc_adj', tableName, event, "PERC_MOD", tbodyName, true, stressorFunction, false, all_stressors_per_habitat)

    @$('.stressor_perc_tot').click (event) =>
      @renderSort('stressor_perc_tot', tableName,  event, "PERC_TOT", tbodyName, true, stressorFunction, false, all_stressors_per_habitat)

    @renderSort('PERC_MOD', tableName, undefined, "PERC_MOD", tbodyName, true, stressorFunction, false, all_stressors_per_habitat)
    
  #do the sorting - should be table independent
  renderSort: (name, tableName, event, sortBy, tbodyName, isFloat, getRowStringValue, reallySortUp, all_stressors_per_habitat) =>
    if event
      event.preventDefault()

    targetColumn = @getSelectedColumn(event, name)

    sortUp = @getSortDir(targetColumn)

    #get the current set from the dropdown 
    name = @$('.chosen-habs').val()

    stressors = _.filter all_stressors_per_habitat, (r) -> r.SC_ID == name


    data = _.sortBy stressors, (row) -> row.NAME
    show_nonzero = @$('.show_nonzero')[0].checked

    if show_nonzero
      data = _.filter data, (row) -> row.PERC_TOT > 0.0
      #flip sorting if needed
    if sortUp || reallySortUp
      data.reverse()

    if sortBy == 'PERC_MOD'
      #flip sorting if needed
      data.reverse()
      if sortUp
        data = _.sortBy(data, 'MOD_VAL_UP')
      else
        data = _.sortBy(data, 'MOD_VAL_DOWN')
    else if sortBy != 'NAME'
      data = _.sortBy data, (row) ->  parseFloat(row[sortBy])
      #flip sorting if needed
      if sortUp
        data.reverse()

    el = @$(tbodyName)[0]
    hab_body = d3.select(el)
    #remove old rows
    hab_body.selectAll("tr.stressor_rows")
      .remove()

    if data?.length > 0
      @$('.no-stressor-results').hide()
      rows = hab_body.selectAll("tr")
        .data(data)
      .enter().insert("tr", ":first-child")
      .attr("class", (d) -> 
        if d.IS_MOD
          return "stressor_rows is_mod" 
        else
          return "stressor_rows not_mod"
        )

      columns = getRowStringValue
      cells = rows.selectAll("td")
          .data((row, i) ->columns.map (column) -> (column: column, value: row[column]))
        .enter()
        .append("td").text((d, i) -> 
          d.value
        )    
    else
      @$('.no-stressor-results').show()

    @setNewSortDir(targetColumn, sortUp)

    @setSortingColor(event, tableName)
    
    #fire the event for the active page if pagination is present
    #no pagination yet for this project
    @firePagination(tableName)
    if event
      event.stopPropagation()

  setSortingColor: (event, tableName) =>
    sortingClass = "sorting_col"
    if event
      parent = $(event.currentTarget).parent()
      newTargetName = event.currentTarget.className
      targetStr = tableName+" th.sorting_col a"  
      if @$(targetStr) and @$(targetStr)[0] 
        oldTargetName = @$(targetStr)[0].className
        
        if newTargetName != oldTargetName
          #remove it from old 
          headerName = tableName+" th.sorting_col"
          @$(headerName).removeClass(sortingClass)
          #and add it to new
          parent.addClass(sortingClass)

  setNewSortDir: (targetColumn, sortUp) =>
    #and switch it
    if sortUp
      @$('.'+targetColumn).removeClass('sort_up')
      @$('.'+targetColumn).addClass('sort_down')
    else
      @$('.'+targetColumn).addClass('sort_up')
      @$('.'+targetColumn).removeClass('sort_down')

  getSortDir: (targetColumn) =>
     sortup = @$('.'+targetColumn).hasClass("sort_up")
     return sortup

  getSelectedColumn: (event, name) =>
    if event
      #get sort order
      targetColumn = event.currentTarget.className
      multiClasses = targetColumn.split(' ')
      #protectedMammals = _.sortBy protectedMammals, (row) -> parseInt(row.Count)
      stressorClassName =_.find multiClasses, (classname) -> 
        classname.lastIndexOf('stressor',0) == 0
      targetColumn = stressorClassName
    else
      #when there is no event, first time table is filled
      targetColumn = name

    return targetColumn

  firePagination: (tableName) =>
    el = @$(tableName)[0]
    hab_table = d3.select(el)
    active_page = hab_table.selectAll(".active a")
    if active_page and active_page[0] and active_page[0][0]
      if active_page[0][0]
        active_page[0][0].click()
module.exports = OverviewTab