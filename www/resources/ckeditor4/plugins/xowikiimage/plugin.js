
var xowikiimage_dialog = $("<div class='xowikiimage_dialog'>X</div>");

xowikiimage_dialog.dialog({
    modal: true, 
    width: '715px', 
    autoOpen: false, 
    zIndex: 10000
});

CKEDITOR.plugins.add( 'xowikiimage', {
    lang : [ 'en', 'de' ],
   
    init : function( editor ) {
	var pluginName = 'xowikiimage';

	editor.addCommand(pluginName, { 
	    exec: function(editor) {
		xowikiimage_dialog.load(editor.config.imageSelectorDialog, {parent_id: editor.config.parent_id}, function() { 
		    xowikiimage_dialog.dialog({title:editor.lang.xowikiimage['insertImage']});
		    xowikiimage_dialog.dialog("open");
		    xowikiimage_dialog.find('input').keypress(function(e) {
			if ((e.which && e.which == 13) || (e.keyCode && e.keyCode == 13)) {
			    return false;
			}
		    });
		    xowikiimage_dialog.find("#insert_form").submit(function() {
			var pathname = window.location.pathname;
			pathname = pathname.substr(pathname.lastIndexOf("/")+1,pathname.length)
			insert_the_image(xowikiimage_dialog.find("#f_url").val().replace(/file:/g, "image:"),
					 pathname+'/'+xowikiimage_dialog.find("#f_url").val()+'?m=download',
					 editor);
			xowikiimage_dialog.dialog("close");
			return false;
		    });
		});
	    }});

	// Register the toolbar button.
	editor.ui.addButton( 'xowikiImage', {
	    label : editor.lang.xowikiimage['insertImage'],
	    command : pluginName,
	    icon: this.path + 'images/image.gif'
	});
    }
} );


var insert_the_image=function (me,src,editor) {
    editor.insertHtml("<img alt=\".SELF./"+me+"\" src=\""+src+"\" type=\"wikilink\" />");
    //editor.insertHtml(me);
}

