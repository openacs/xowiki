/*
 * A simple drag and drop handler based on YUI for lists to be used
 * e.g. with the the form-fields of type abstract_page (e.g. form_page
 * or page) with mutliple entries.
 *
 * The handler knows about the CSS class textarea.selection, makes it
 * invisible and replaces it by a list (selected items). It handles
 * actually ULs of class region which are treated as candidates. The
 * candidates list is build by the application. On drag and drop, this code 
 * maintains the entries in textarea.
 * 
 *
 * Gustaf Neumann                      fecit April 2009
 */
YAHOO.namespace('xo_sel_area');

YAHOO.xo_sel_area.DragnDrop = function() {

    var Dom = YAHOO.util.Dom;
    var Event = YAHOO.util.Event;
    var DDM = YAHOO.util.DragDropMgr;

YAHOO.xo_sel_area.DDApp = {
    dict: new Array(),
    values: new Array(),

    init: function() {
       // console.log("init called");
       // console.info(this);
       //
       // Find all textareas which class selection (maybe further restrict in the future)
       var textareas = YAHOO.util.Selector.query('textarea.selection');
       for (var i = 0; i < textareas.length; i++) {
         var textarea = textareas[i];
         // We found such an textarea. The lines of the textarea are
         // treated as the selected values (internal representations).
         var items = textarea.value.split(/\n/g);
         var selected_LIs = "";
         // For all these items, build an HTML list with the labels
         // (external representations).
         for (var j = 0; j < items.length; j++) {
           var o = items[j];
           if (o == "") continue;
           selected_LIs += "<li class='selection'>" + this.dict[o] + "</li>\n";
         }

         // Map in the candidates the internal representation to an
         // external one.
         var candidates = document.getElementById(textarea.id + "_candidates");
         var items = candidates.getElementsByTagName("li");
         for (var j = 0; j < items.length; j++) {
           items[j].innerHTML = this.dict[items[j].innerHTML];
         }
         
         // Insert the generated HTML list and hide the textarea
         var html = "<ul id='" + textarea.id + "_selection' class='region'>\n" + selected_LIs + "</ul>\n";
         textarea.style.display = "none";
         var div = document.createElement('div');
         div.innerHTML = html;
         Dom.insertBefore(div,textarea);
         //console.log(html);
       }

       // Ok, now we use standard drag and drop, modeled around the
       // example from YUI dnd. We have now two HTML lists to be
       // handled as regions for drag and drop.
       var regions = YAHOO.util.Selector.query('ul.region');
       for (var i = 0; i < regions.length; i++) {
         new YAHOO.util.DDTarget(regions[i].id);
         var items = regions[i].getElementsByTagName("li");
         for (var j = 0; j < items.length; j++) {
           var id = regions[i].id + '__' + j;
           // setting the ids (note: will overwrite prexising ids on dnd items)
           items[j].id = id;
           new YAHOO.xo_sel_area.DDList(id);
         }
       }
    },
    
    build_selection: function(id) {
       // We get called with the id of the drop target (the list)
       var selection_id;
       if (id.match(/_selection$/)) {
         selection_id = id.replace(/_selection$/,"");
       } else {
         selection_id = id.replace(/_candidates$/,"");
       }
       // console.log("selection_id " + selection_id);

       var textarea = document.getElementById(selection_id);
       var selection_list =  document.getElementById(selection_id + "_selection");
       var items = selection_list.getElementsByTagName("li");
       var values = "";
       var aux_div = document.createElement('div');
       for (var j = 0; j < items.length; j++) {
         var item = items[j];
         aux_div.innerHTML = item.innerHTML;
         var index = aux_div.firstChild.nodeValue;
         if (this.values[index] == undefined ) {
           console.log("   undefined : " + index);
           console.info(this);
           console.info(YAHOO.xo_sel_area.DDApp);
           for (var i = 0; i < this.values.length; i++) {
             console.log("      defined : "+ this.values[i]);
           }
         } else {
           values += this.values[index] + "\n";
         }
       }
       textarea.value = values;
  },

};

/////////////////////////////////////////////////////////////////////////////
// custom drag and drop implementation
//////////////////////////////////////////////////////////////////////////////

YAHOO.xo_sel_area.DDList = function(id, sGroup, config) {

    YAHOO.xo_sel_area.DDList.superclass.constructor.call(this, id, sGroup, config);

    var el = this.getDragEl();
    Dom.setStyle(el, "opacity", 0.67); // The proxy is slightly transparent

    this.goingUp = false;
    this.lastY = 0;
};

YAHOO.extend(YAHOO.xo_sel_area.DDList, YAHOO.util.DDProxy, {

    startDrag: function(x, y) {

        // make the proxy look like the source element
        var dragEl = this.getDragEl();
        var clickEl = this.getEl();
        Dom.setStyle(clickEl, "visibility", "hidden");

        dragEl.innerHTML = clickEl.innerHTML;

        Dom.setStyle(dragEl, "color", Dom.getStyle(clickEl, "color"));
        Dom.setStyle(dragEl, "backgroundColor", Dom.getStyle(clickEl, "backgroundColor"));
        Dom.setStyle(dragEl, "border", "2px solid gray");
    },

    endDrag: function(e) {

        var srcEl = this.getEl();
        var proxy = this.getDragEl();

        // Show the proxy element and animate it to the src element's location
        Dom.setStyle(proxy, "visibility", "");
        var a = new YAHOO.util.Motion( 
            proxy, { 
                points: { 
                    to: Dom.getXY(srcEl)
                }
            }, 
            0.2, 
            YAHOO.util.Easing.easeOut 
        )
        var proxyid = proxy.id;
        var thisid = this.id;

        // Hide the proxy and show the source element when finished with the animation
        a.onComplete.subscribe(function() {
                Dom.setStyle(proxyid, "visibility", "hidden");
                Dom.setStyle(thisid, "visibility", "");
            });
        a.animate();
    },

    onDragDrop: function(e, id) {

        // If there is one drop interaction, the li was dropped either on the list,
        // or it was dropped on the current location of the source element.
        if (DDM.interactionInfo.drop.length === 1) {

            // The position of the cursor at the time of the drop (YAHOO.util.Point)
            var pt = DDM.interactionInfo.point; 

            // The region occupied by the source element at the time of the drop
            var region = DDM.interactionInfo.sourceRegion; 

            // Check to see if we are over the source element's location.  We will
            // append to the bottom of the list once we are sure it was a drop in
            // the negative space (the area of the list without any list items)
            if (!region.intersect(pt)) {
                var destEl = Dom.get(id);
                var destDD = DDM.getDDById(id);
                destEl.appendChild(this.getEl());
                destDD.isEmpty = false;
                DDM.refreshCache();
            }

        }
        YAHOO.xo_sel_area.DDApp.build_selection(id);
    },

    onDrag: function(e) {

        // Keep track of the direction of the drag for use during onDragOver
        var y = Event.getPageY(e);

        if (y < this.lastY) {
            this.goingUp = true;
        } else if (y > this.lastY) {
            this.goingUp = false;
        }

        this.lastY = y;
    },

    onDragOver: function(e, id) {
    
        var srcEl = this.getEl();
        var destEl = Dom.get(id);

        // We are only concerned with list items, we ignore the dragover
        // notifications for the list.
        if (destEl.nodeName.toLowerCase() == "li") {
            var orig_p = srcEl.parentNode;
            var p = destEl.parentNode;

            if (this.goingUp) {
                p.insertBefore(srcEl, destEl); // insert above
            } else {
                p.insertBefore(srcEl, destEl.nextSibling); // insert below
            }

            DDM.refreshCache();
        }
    }
});

Event.onDOMReady(YAHOO.xo_sel_area.DDApp.init, YAHOO.xo_sel_area.DDApp, true);
};

YAHOO.xo_sel_area.DragnDrop();

