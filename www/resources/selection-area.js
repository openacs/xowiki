/*
 * A simple drag and drop handler for HTML5, similar to the old YUI
 * handler for lists. This code interacts with the formfield class
 * "candidate_box_select".
 *
 * The CSS part of this handler is placed in xowiki.css, rooted by a
 * div.candidate-selection.
 *
 * The candidate selection is based on two lists, the "candidates" and
 * the "selection". The user can drag values from the "candidates" to
 * the selection and vice versa. Then the form is submitted, the
 * internal representation of the selection is transferred to the server
 * (by using a hidden textarea).
 *
 * Gustaf Neumann                      fecit May 2019
 */

function selection_area_dragstart_handler(ev) {
    // Add the target element's id to the data transfer object
    ev.dataTransfer.setData("text/plain", ev.target.id);
    ev.dataTransfer.dropEffect = "move";
}

function selection_area_dragover_handler(ev) {
    ev.preventDefault();
    // Set the dropEffect to move
    ev.dataTransfer.dropEffect = "move"
}

function selection_area_drop_handler(ev) {
    ev.preventDefault();
    //console.log("drop_handler on " + ev.target.nodeName);

    // Get the dropped element based on the transferred ID.
    var sourceElement = document.getElementById(ev.dataTransfer.getData("text/plain"))

    // Get the target UL, which should be updated with the dropped
    // item.
    if (ev.target.nodeName == "UL") {
        var ul =  ev.target;
    } else  if (ev.target.nodeName == "LI") {
        var ul =  ev.target.parentElement;
    } else {
        console.log("unexpected target " + ev.target);
    }

    // Reparent the dropped item
    ul.appendChild(sourceElement);

    var id = ul.parentElement.parentElement.id;
    selection_area_update_internal_representation(id);
}

function selection_area_update_internal_representation (id) {
    // Update the internal representation based on the data-element of
    // the list items.
    var textarea = document.getElementById(id + ".text");
    var items    = document.getElementById(id + ".selected").getElementsByTagName('LI');
    var internalRep = "";

    for (var j = 0; j < items.length; j++) {
        internalRep += items[j].dataset.value + "\n";
    }

    textarea.value = internalRep;

    selection_area_update_count_information(id);
}

function selection_area_bulk_operation_handler(ev, operation) {
    if (operation == 'bulk_add') {
        var source_class = '.candidates';
        var destination_class = '.selected';
    } else {
        // bulk_remove operation
        var source_class = '.selected';
        var destination_class = '.candidates';
    }

    var id          = ev.target.previousSibling.parentElement.parentElement.id;
    var source      = document.getElementById(id + source_class).getElementsByTagName('LI');
    var destination = document.getElementById(id + destination_class);

    // Reparent all source items
    while(source.length > 0) {
        destination.appendChild(source[0]);
    }

    selection_area_update_internal_representation(id);
}

function selection_area_update_count_information(id) {
    // Update the count information for the listings
    for (var element of ['candidates', 'selected']) {
        // get the list elements
        var list_elements  = document.getElementById(id + '.' + element).getElementsByTagName('LI');

        // get the list header element
        var list_header = document.getElementById(id).getElementsByClassName('workarea ' + element)[0].getElementsByTagName('H3')[0];

        // replace the count information e.g. "Selection (0)" -> "Selection (1)"
        list_header.innerHTML = list_header.innerHTML.replace(/\(.*\)/,'(' + list_elements.length + ')');
    }
}

/*
 * Local variables:
 *    mode: JavaScript
 *    indent-tabs-mode: nil
 * End:
 */
