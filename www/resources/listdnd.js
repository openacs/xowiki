/*
 * Drag and drop for reordering table of contents (toc) items based on
 * the tree renderer "listdnd" using HTML5. This code is intended to
 * behave similar as the previous solution based on YUI2.
 *
 * The CSS part of this handler is placed in xowiki.css, using the
 * classes "page_order_region", "page_order_region_no_target",
 * "mark-above", "mark-below".
 *
 * In essence, the implementation uses darag and drop of list items
 * between potentially different lists and issues AJAX requests to the
 * backend to reflect these changes in the database. Since the order
 * of the items in a "toc" is determiend by the "page_order" attribute
 * in the database, it reports the changed lists of page_orders back.
 *
 * The implementation uses the following data attributes: 
 *  - <li>  data-value (containing page_order)
 *  - <div> data-folder_id data-package_url (for reporting to the backend)
 * 
 * Gustaf Neumann                      fecit May 2019
 */

function listdnd_get_parent( target, nodeName ) {
    while ( target.nodeName != nodeName && target.nodeName != 'BODY' ) {
        target = target.parentNode;
    }
    if ( target.nodeName == 'BODY' ) {
        return false;
    } else {
        return target;
    }
}

function listdnd_page_orders( element ) {
    //
    // Collect the page_orders of the LI items below the given element
    // and return it in form of an array.
    //
    var items = element.getElementsByTagName('LI');
    var result = [];

    for (var j = 0; j < items.length; j++) {
	var page_order = items[j].dataset.value;
	if (page_order != '') {
	    result.push(page_order);
	}
    }
    return result;
}

function listdnd_dragstart_handler(ev) {
    // Add the target element's id to the data transfer object
    var target = listdnd_get_parent( ev.target, 'LI' );
    ev.dataTransfer.setData("text/plain", target.id);
    ev.dataTransfer.dropEffect = "move";
    //console.log("listdnd_dragstart_handler on " + target.id);
}

function listdnd_dragover_handler(ev) {
    ev.preventDefault();
    ev.dataTransfer.dropEffect = "move"
    var target = listdnd_get_parent( ev.target, 'LI' );
    var value = target.dataset.value;
    if (typeof value !== 'undefined') {
	var bounding = target.getBoundingClientRect()
	var offset = bounding.y + (bounding.height/2);
	if ( event.clientY - offset > 0 ) {
	    target.classList.add('mark-below')
	    target.classList.remove('mark-above')	    
	} else {
	    target.classList.add('mark-above')
	    target.classList.remove('mark-below')	    
	}
    }
}

function listdnd_dragleave_handler(ev) {
    ev.preventDefault();
    // Set the dropEffect to move
    ev.dataTransfer.dropEffect = "move"
    var target = listdnd_get_parent( ev.target, 'LI' );
    target.classList.remove('mark-above', 'mark-below');
}


function listdnd_drop_handler(ev) {
    ev.preventDefault();
    //console.log("drop_handler on " + ev.target.nodeName);

    // Get the dropped element based on the transferred ID.
    var sourceElement = document.getElementById(ev.dataTransfer.getData("text/plain"))

    // We want to allow only drops on elements having a "data-value"
    // attribute set (because of desisred reorderings of the page_order)
    var target = listdnd_get_parent( ev.target, 'LI');

    var value = target.dataset.value;
    if (typeof value !== 'undefined') {
	
	// Used variables:
	//   - dropul: The target ul, which should be updated with
	//             the dropped item.
	//   - div:    The outer did, needed for obtaining "folder_id"
	//             and "package_url".
	//   - before: collection of "page_orders" before drop.
	//   - after:  collection of "page_orders" after drop.
	//
	var dropul = target.parentNode;
	var div    = listdnd_get_parent( target.parentNode, 'DIV');
	var before = listdnd_page_orders(dropul);
	
	if ( target.classList.contains('mark-above') ) {
	    target.classList.remove('mark-above')
	    target.parentNode.insertBefore(sourceElement, target);
	} else {
	    target.classList.remove('mark-below')
	    target.parentNode.insertBefore(sourceElement, target.nextSibling);
	}
	
	var after = listdnd_page_orders(dropul);
	var diff = after.filter(x => !before.includes(x) );
	
	//console.log('drop before <' + before + '> after <' + after + '> diff <' + diff + '>');
	
	var data = 'change-page-order=1' +
            '&from='      + escape(before.join(' ')) +
            '&to='        + escape(after.join(' ')) +
	    '&clean='     + escape(diff.join(' ')) +
            '&folder_id=' + escape(div.dataset.folder_id) +	
	    '';

	//console.log('package_url <' + div.dataset.package_url + '>');
	if (1) {
	    var request = new XMLHttpRequest();
	    request.onload =  function(e) {
		// There seems no good way to handle redirects (301 or
		// 302) in XHR. Since we know valid results (just the
		// "OK"), everything else must have been a
		// redirect. We could be brutal and display the
		// returned page, but not sure, if this would be
		// desirable either.
		if (this.getResponseHeader["Content-Length"] > 10) {
		    // there must have happened a redirect
		    alert("Refresh your login and redo update");
		    window.location.href = div.dataset.package_url 
			+ "?refresh-login&return_url=" 
			+ escape(window.location.href);
		} else {
		    window.location.reload();
		}
	    };
	    request.open('POST', div.dataset.package_url, true);
	    request.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
	    request.send(data);
	}
    }
}
