/*
 * A simple drag and drop handler for HTML5, simlar to the old YUI
 * handler for lists. This code interacts with the formfield class
 * "candidate_box_select".
 *
 * The CSS part of this handler is placed in xowiki.css, rooted by a
 * div.candidate-selection.
 *
 * The candidate selection is based on two lists, the "candidates" and
 * the "selection". The user can drag values from the "candidates" to
 * the selection and vice versa. Then the form is submitted, the
 * internal representation of the selection is tranfered to the server
 * (by using a hidden textarea).
 *
 * Gustaf Neumann                      fecit May 2019
 */

function dragstart_handler(ev) {
    // Add the target element's id to the data transfer object
    ev.dataTransfer.setData("text/plain", ev.target.id);
    ev.dataTransfer.dropEffect = "move";
}

function dragover_handler(ev) {
    ev.preventDefault();
    // Set the dropEffect to move
    ev.dataTransfer.dropEffect = "move"
}

function drop_handler(ev) {
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

    // Update the internal representation based on the data-element of
    // the list items.
    var id       = ul.parentElement.parentElement.id;
    var textarea = document.getElementById(id + ".text");
    var items    = document.getElementById(id + ".selected").getElementsByTagName('LI');
    var internalRep = "";

    for (var j = 0; j < items.length; j++) {
	internalRep += items[j].dataset.value + "\n";
    }

    textarea.value = internalRep;
}
