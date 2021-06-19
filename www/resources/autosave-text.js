/*
 * A simple autosave handler for plain text widgets. This handler was
 * developed for the textarea formfield, as used by the test-item
 * procs, but might be as well used for other purposes. A handler is
 * registered for key-strokes, and after a certain idle_time (in ms),
 * the content of the widget pointed to by the proveided ID is sent
 * via AJAX. The POST URL is taken from the form, but the suffix
 * "m=autosave-attribute" is appended ot it (xowiki method call).
 *
 * This script does not depend on extanal helper such as jquery.
 *
 * Gustaf Neumann                      fecit May 2020
 */

var autosave_timeoutID = {};
var autosave_idleTime = 10000;

function autosave_save_contents(id) {
    var content = document.getElementById(id);
    //console.log('autosave_save_contents ' + content.value + '> name ' + content.name + ' url ' + content.form.action) ;
    var url = new URL(content.form.action);
    url.search = "?m=autosave-attribute";

    // Save the data via AJAX call
    var xhttp = new XMLHttpRequest();
    var data = new FormData();
    xhttp.open("POST", url.href, true);
    xhttp.autosaveID = id;
    data.append(content.name, content.value);
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            //console.log('saved <' + this.responseText  + '>') ;
            var status = document.getElementById(this.autosaveID + '-status');
            if (this.responseText == "ok") {
                status.setAttribute('class', 'saved');
                status.textContent = status.dataset.saved;
            } else {
                status.textContent = status.dataset.rejected;
            }
        } else {
            //console.log('not saved status ' + this.status + '  this.readyState ' + this.readyState ) ;
        }
    };
    xhttp.send(data);
};

function autosave_handler(id) {
    var status = document.getElementById(id + '-status');
    //console.log('autosave_handler ' + id + ' ' + status);
    status.setAttribute('class', 'pending');
    status.textContent = status.dataset.pending;
    if (id in autosave_timeoutID) {
        clearTimeout(autosave_timeoutID[id]);
    }
    autosave_timeoutID[id] = setTimeout(autosave_save_contents, autosave_idleTime, id);
};

/*
 * Local variables:
 *    mode: JavaScript
 *    indent-tabs-mode: nil
 * End:
 */
