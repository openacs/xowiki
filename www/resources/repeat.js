var xowiki = xowiki || {};
xowiki.repeat = {};
/*
 * addItem
 *
 * Add an item to the container if nrItems is below maximum. Actually,
 * this function just invisible items visible.
 */
xowiki.repeat.addItem = function(e, json) {
    var data = eval("(" + json + ')');
    var items = $(e.parentNode).children(".repeatable:hidden");
    var currentItem = '';
    // the loop starts with 1 because items[0] is the template
    for (var j = 1; j < items.length; j++) {
        currentItem = items[j];
        if (currentItem.nodeName != 'DIV') { continue; }
        if (currentItem.style.display == 'none') {
            if (j == (items.length)-1) {
                // this is the final item: hide add item button
                $(e.parentNode).children(".repeat-add-link").hide();
            }
            // Make an existing but invisible item visible.
            currentItem.style.display = 'block';

            // IPAD HACK START
            // for ipad we have to set the contenteditiable to true for the ckeditor inline if it is false
            var ck_editors = $(currentItem.find('.xowiki-ckeditor.cke_editable.cke_editable_inline.cke_contents_ltr'));
            for (var k = 0; k < ck_editors.length; k++) {
                if ($(ck_editors[k]).attr('contenteditable') == 'false') {
                    console.log('we have to set the contenteditable to true');
                    $(ck_editors[k]).attr('contenteditable','true');
                }
            }
            // IPAD HACK ENDE

            break;
        }
    }

    $(".xowiki-ckeditor", currentItem).each(function (i,e) {
      //console.debug('load ckeditor' +e.id);
      if ($(e).is(':visible')) {
        var functionname = 'load_' + e.id;
         try {
            window[functionname]();
         } catch(err) {
            //console.log('function: ' + functionname + ' not found');
         }
      }
    });

    // We could add another item here by adding a copy of the template
    // and renaming the field like in delItems. We have to care as
    // well in RepeatContainer.initialize() to check, how many
    // subcomponents must be generated in advance (not max as now).
    console.log('could add one more, j ' + j);
    console.info(data);
    return false;
};

/*
 * itemStats
 *
 * Collect statistics of a repeatable container. This function computes
 * the number of visible items, total items, the current item index
 * and the div-nodes containing the items.
 */
xowiki.repeat.itemStats = function(item) {
    var items = item.parentNode.children;
    var visible = 0;
    var nr = 0;
    var divs = new Array();
    var current = -1;
    for (var j = 0; j < items.length; j++) {
        if (items[j].nodeName != 'DIV') { continue; }
        if (items[j].style.display != 'none') { visible ++; }
        if (items[j] == item) {current = nr;};
        divs[nr] = items[j];
        nr ++;
    }
    return {'visible' : visible, 'nr' : nr, 'current': current, 'divs' : divs};
}

/*
 * renameItem
 *
 * Search in the dom tree for input names and rename it based on the
 * provided stem.
 */
xowiki.repeat.renameItem = function(top, e, from, to) {
    if (e == undefined) {return;}
    //console.log('renameItem: work on ' + e.nodeName + ' ' + from + ' ' + to);
    //console.info(e);
    var items = e.children;
    if (items.length == 0 || e.nodeName == 'SELECT') {
        var name = e.name;
        if (typeof name != "undefined" && name != "") {
            //console.log('renameItem: compare ' + name + ' from ' + from);
            var compareLength = from.length;
            if (name.substring(0,compareLength) == from) {
                //console.log('renameItem: RENAME ' + name + ' from ' + from);
                if (compareLength != name.length) {
                    to += name.substring(compareLength, name.length);
                }
                e.name = to;
                e.disabled = false;
                // we have also to remove the disabled attribute for options of a select field
                if (e.nodeName == 'SELECT') {
                    $(e).find('option:disabled').each(function() {
                        $(this).attr('disabled', false);
                    });
                }

                //console.log('renameItem: renamed ' + name + ' base ' + from + ' to ' + to);
                //this.renameItem(top, top,
                  //              '__old_value_' + from,
                    //            '__old_value_' + to);
            }
        }
    } else if (e.nodeName == 'DIV' || e.nodeName == 'FIELDSET') {
        for (var j = 0; j < items.length; j++) {
            this.renameItem(top, items[j], from, to);
        }
    } else {
        console.log('rename ignores ' + e);
    }
}

/*
 * delItem
 *
 * Delete the current item. Actually, this implementation overwrites the
 * current item with the template item, moves it to the end and renames
 * the fields.
 */
xowiki.repeat.delItem = function(e, json) {
    var data = eval("(" + json + ')');
    var item = e.parentNode;
    var stats =  this.itemStats(item);
    //console.info(item);
    console.info(stats);
    //console.info(data);

    var current = stats['current'];
    var last    = stats['visible'];
    var items   = item.parentNode.children;
    var divs    = stats['divs'];
    //console.info(divs);
    var display = 'none';

    if (stats['visible'] < data['min']+1) {
        // we have reached the minimum
        // so we simulate that the current item is the last one -> it is reset by the template
        // the only difference is that we shouldn't hide it
        last = current;
        display = 'block';
    }

    console.log('delete ' + current);

    if (current == last) {
        //console.log('delete the last item');
    } else {
        for (var j = current; j < last; j++) {
            var k = j + 1;

            //console.log('work on ' + j + ': ' + divs[j].innerHTML);

            // before moving, we are storing the input values --> so that the values are being moved
            // normal input fields
            $(divs[k]).find(':input[type=text]').each(function() {
                $(this).attr('value',$(this).val());
            });

            // radio and checkbox input fields
            // THIS DOES NOT SEEM TO WORK
            $(divs[k]).find(':input[type=radio]').each(function() {
                //console.info($(this));
                $(this).prop('checked', $(this).checked);
            });

            // checkbox input fields
            $(divs[k]).find(':input[type=checkbox]:checked').each(function() {
                $(this).attr('checked',$(this).attr('checked'));
            });
            // selected options of select fields
            $(divs[k]).find(':selected').each(function() {
                $(this).attr('selected','on');
            });

            // textarea
            $(divs[k]).find('textarea').each(function() {
                $(this).html($(this).val());
            });

            var oldid = item.parentNode.id + '.' + k;
            var newid = item.parentNode.id + '.' + j;

            // before we can move the items we have to remove the ckeditor instance if available
            // otherwise it will shown twice after moving (because we are reloading it)
            // we have to reload because the ckeditor will not work after moving
            // additionally we have to set the content of the ckeditor in the textarea
            if (typeof CKEDITOR != "undefined") {
                // we are selecting all ckeditor intances which are at the same level and below of the current item
                for (var l in CKEDITOR.instances) {
                    // console.log('instance name: ' + CKEDITOR.instances[l].name);
                    var searchString = item.parentNode.id + k;
                    // the instance names of the ckeditor are without '. : -' --> see also initialize of ckeditor
                    searchString = searchString.replace(/[.:-]/g,'');

                    // console.log('searchString: '+searchString);
                    if (CKEDITOR.instances[l].name.search(searchString) == 0) {
                        // console.log('data to copy: '+CKEDITOR.instances[l].getData());
                        // should update the textarea but it doesn't -> so we have to do that manually
                        CKEDITOR.instances[l].updateElement();
                        document.getElementById(CKEDITOR.instances[l].name).innerHTML=CKEDITOR.instances[l].getData();

                        CKEDITOR.instances[l].destroy(true);
                    }
                }
            }
            //console.log(j + ' becomes ' + k + ': ' + divs[k].innerHTML);
            divs[j].innerHTML = divs[k].innerHTML;


            // due to the fact that the ckeditor are using the ids for reloading
            // we have to recycle them (and for the other cases it doesn't hurt)
            this.renameIds(divs[j], oldid, newid);
            //console.log("RENAME INNER");
            this.renameItem(divs[j], divs[j],
                            data['name'] + '.' + (k), data['name'] + '.' + (j));
        }
    };
    // We add an empty item at the end to force back-reporting of
    // empty content to the instance variables. Otherwise the old
    // content would stay. This means, that we should never physically
    // delete items.
    divs[last].innerHTML = divs[0].innerHTML;

    var templateid = item.parentNode.id + '.0';
    var newid = item.parentNode.id + '.' + last;

    // due to the fact that the ckeditor are using the ids for reloading we have to recycle them (and for the other cases it doesn't hurt)
    this.renameIds(divs[last],templateid,newid);

    // ckeditor releoding
    // we are selecting all ckeditor intances which are at the same level and below of the current item
    // so we can be sure that in case of a compound field all editors are reloaded correctly
    // .xowiki-ckeditor --> normaler ckeditor
    // .xowiki-ckeditor.ckeip --> inplace editor
    // .xowiki-ckeditor.cke_editable.cke_editable_inline.cke_contents_ltr --> inline editing
    var ckclasses = [".xowiki-ckeditor",
                     ".xowiki-ckeditor.ckeip",
                     ".xowiki-ckeditor.cke_editable.cke_editable_inline.cke_contents_ltr"];
    for (var i = 0; i < ckclasses.length; i++) {
        var ck_editors = $(item.parentNode).find(ckclasses[i]);
        for (var j = 0; j < ck_editors.length; j++) {
            var idofeditor = ck_editors[j].id;
            console.log('reloading ckeditor for id: ' + idofeditor);
            var functionname = 'load_' + idofeditor;
            try {
                window[functionname]();
            } catch(err) {
                console.log('function: ' + functionname + ' not found maybe it is a template');
            }
        }
    }

    //console.log("RENAME LAST");
    this.renameItem(divs[last], divs[last],
                    data['name'] + '.0', data['name'] + '.' + (last));

    divs[last].style.display = display;

    // force refresh of tree
    item.parentNode.style.display = 'none';
    item.parentNode.style.display = 'block';

    // make sure add item link is visible
    $(item.parentNode).children(".repeat-add-link").show();

    //console.log('final html ' + item.parentNode.innerHTML);
    return false;
};


/*
 * renameIds
 *
 * Rename all ids (also children) from the current element
 * which matches somewhere the searchString and replace the parts
 * with the replaceString
 * example:
 *    e: id = "ckeip_Fendefvar40"
 *    searchString: Fendefvar40
 *    replaceString: Fendefvar41
 * result: ckeip_Fendefvar40 -> ckeip_Fendefvar41
 */
xowiki.repeat.renameIds = function(e, searchString, replaceString) {
    $(e).find('[id*="'+searchString+'"]').each(function() {
        var tmpid = $(this).attr("id");
        tmpid = tmpid.replace(searchString,replaceString);
        $(this).attr("id", tmpid);
    });

    // the instance names of the ckeditor are without '. : -' --> see also initialize of ckeditor
    searchString = searchString.replace(/[.:-]/g,'');
    replaceString = replaceString.replace(/[.:-]/g,'');

    $(e).find('[id*="'+searchString+'"]').each(function() {
        var tmpid = $(this).attr("id");
        tmpid = tmpid.replace(searchString,replaceString);
        $(this).attr("id", tmpid);
    });
}

/*
 * Local variables:
 *    mode: Javascript
 *    indent-tabs-mode: nil
 * End:
 */
