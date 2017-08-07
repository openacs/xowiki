/*
 * A simple drag and drop handler based on YUI for lists to be used
 * e.g. with the book includelet. 
 *
 * The handler knows about the two CSS
 * classes page_order_region and page_order_region_no_target, where
 * page_order_regions are used for drag and drop. The handler
 * maintains client data (cd) associated with the list items, which
 * has to be initialized by the application.
 *
 * Note: it might not be a good idea to use this with large list
 * structures asi it is, since the drag-proxy might be quite large.
 *
 * Example usage with the book includelet:
 *
 *   {{book -menu_buttons "edit create delete" -allow_reorder 2}} 
 * 
 * which means: only support drag&drop starting with the 2nd level
 *
 * Gustaf Neumann                      fecit April 2009
 */

YAHOO.namespace('xo_page_order_region');

YAHOO.xo_page_order_region.DragnDrop = function() {

    var Dom = YAHOO.util.Dom;
    var Event = YAHOO.util.Event;
    var DDM = YAHOO.util.DragDropMgr;

YAHOO.xo_page_order_region.DDApp = {
    with_DDTarget: 1,

    package_url: "",
    cd: new Array(),
    source_region: new Array(),
    level: new Array(),
    highest_level: 0,
    highest_region: 0,

    init: function() {
       // Ok, now we use standard drag and drop, modeled around the
       // example from YUI dnd. We have now two HTML lists to be
       // handled as regions for drag and drop.
       //var regions = YAHOO.util.Selector.query('ul.page_order_region');
       //var regions = YAHOO.util.Selector.query('ul.page_order_region, ul.page_order_region_no_target');
       var regions = YAHOO.util.Selector.query('ul.page_order_region');
       for (var i = 0; i < regions.length; i++) {

         if (this.with_DDTarget) {
           new YAHOO.util.DDTarget(regions[i].id);
         }

         // compute the order of items per region
         var order = "";
         var items = regions[i].childNodes;

         for (var j = 0; j < items.length; j++) {
           if (items[j].nodeName != 'LI') {continue;}
           var iid = items[j].id;
           // add the DDList only for list items in UL with class
           // "page_order_region"
           if (YAHOO.util.Dom.hasClass(regions[i],"page_order_region")) {
             new YAHOO.xo_page_order_region.DDList(iid);
           }

           // console.log(iid + " => " +  this.cd[iid] );
           order += this.cd[iid] + " ";
           // Keep as well the source regions
           this.source_region[iid] = regions[i];
         }
         // Finally, remember the level and store the original order.
         this.level[regions[i].id] = this.cd[iid].split(/[.]/g).length;
         this.cd[regions[i].id] = order;
         //console.log("initial region: " + regions[i].id + " => " + order);
       }
    },

    report_level: function(id, e) {
       if (this.level[id] != undefined) {
         // Keep the highest level in case we drop on nested targets
         if (this.highest_level < this.level[id]) {
           this.highest_level = this.level[id];
           this.highest_region = id;
         }
       }
    },

    finish: function(e) {

        //console.log("finish  " + this.highest_region);

       // if we have no highest_region, the drop was not on a drop target
       if (this.highest_region == 0) {
         // get the ul via the provided element. This might not be the
         // list you are expecting, if there are nested lists.
         var ul =  document.getElementById(e.id).parentNode;
         //console.info(ul);
       } else {
         // The variable highest_region is only used, if ul's are
         // defined as DDTargets
         var ul =  document.getElementById(this.highest_region);
       }

       // console.log(this.cd[e.id] + " landed in region "+ ul.id + " => " +  this.cd[ul.id]);

       // Process childNodes of the ul simply to avoid to include
       // nested items
       var order = "";
       var items = ul.childNodes;

       for (var j = 0; j < items.length; j++) {
         if (items[j].nodeName != 'LI') {continue;}
         var iid = items[j].id;
         order += this.cd[iid] + " ";
         //console.log(iid + " => " + this.cd[iid]);
       }

       // console.log(this.cd[ul.id] + " => " + order + " => " + this.cd[this.source_region[e.id].id]);

       if (this.package_url != '' && order != '') {
         this.callback = {
           success: function(o) {
             //console.info(o); There seems no way to handle redirects
             // (301 or 302) in the asyncrequest. Since we know valid
             // results (just the "OK"), everything else must be a
             // redirect. We could be brutal and display the returned
             // page, but not sure, if this would be desirable either.
             if (o.getResponseHeader["Content-Length"] > 10) {
               // there must have happened a redirect
               alert("Refresh your login and redo update");
               window.location.href = this.package_url 
                  + "?refresh-login&return_url=" 
                  + escape(window.location.href);
             } else {
               window.location.reload();
             }
             
           },
           scope: this
         }
         //return;
         YAHOO.util.Connect.asyncRequest('POST', this.package_url, this.callback, 
                                         'change-page-order=1' +
                                         '&from=' + escape(this.cd[ul.id]) +
                                         '&to='  + escape(order) +
                                         '&clean=' + escape(this.cd[this.source_region[e.id].id]));
       }
  }

};

/////////////////////////////////////////////////////////////////////////////
// custom drag and drop implementation
//////////////////////////////////////////////////////////////////////////////

YAHOO.xo_page_order_region.DDList = function(id, sGroup, config) {

    YAHOO.xo_page_order_region.DDList.superclass.constructor.call(this, id, sGroup, config);

    var el = this.getDragEl();
    Dom.setStyle(el, "opacity", 0.67); // The proxy is slightly transparent

    this.goingUp = false;
    this.lastY = 0;
};

YAHOO.extend(YAHOO.xo_page_order_region.DDList, YAHOO.util.DDProxy, {

    startDrag: function(x, y) {

        // make the proxy look like the source element
        var dragEl = this.getDragEl();
        var clickEl = this.getEl();

        Dom.setStyle(clickEl, "visibility", "hidden");
        dragEl.innerHTML = clickEl.innerHTML;

        Dom.setStyle(dragEl, "color", Dom.getStyle(clickEl, "color"));
        Dom.setStyle(dragEl, "backgroundColor", Dom.getStyle(clickEl, "backgroundColor"));
        Dom.setStyle(dragEl, "border", "2px solid gray");
        
        // make sure, this is always initialized
        YAHOO.xo_page_order_region.DDApp.highest_region = 0;
    },

    endDrag: function(e) {
      //console.log("endDrag");
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
        YAHOO.xo_page_order_region.DDApp.finish(this);
    },

    onDragDrop: function(e, id) {
        //console.log("onDragDrop");
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
                //console.log('no intersect');
            } else {
              // console.log('intersect');
           }
        } else {
          // console.log('interactions l=' + DDM.interactionInfo.drop.length);
        }
        YAHOO.xo_page_order_region.DDApp.report_level(id, this);
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

    onDragEnter: function(e, id) {
      var destEl = Dom.get(id);
      var p = destEl.parentNode;
      Dom.setStyle(p, "border", "1px dotted green");
    },

    onDragOut: function(e, id) {
      var destEl = Dom.get(id);
      var p = destEl.parentNode;
      Dom.setStyle(p, "border", "0px");
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

Event.onDOMReady(YAHOO.xo_page_order_region.DDApp.init, YAHOO.xo_page_order_region.DDApp, true);
};

YAHOO.xo_page_order_region.DragnDrop();

