CKEDITOR.plugins.add( 'xowikiimage', {
    requires: ['widget', 'iframedialog','fakeobjects'],
    lang : [ 'en', 'de' ],
    init : function( editor ) {

        var pluginName = 'xowikiimage';
        
        //dialog
        var height = 600;
        var width = 800;

        // CKEDITOR dialog addIframe
        // NOTE: addIframe is not documented well online the parameters (especially src) needed are only seen in source code 
        // addIframe (name, title, src, minWidth, minHeight, [onContentLoad], [userDefinition])
        CKEDITOR.dialog.addIframe('xowikiimage' , 'Image',
            editor.config.imageSelectorDialog, width, height,
            function () {
                domId = this.domId;
                //an ugly bug in ckeditor can lead to tiny iframe dialogs
                $(".cke_dialog_ui_vbox_child").css('width', width);
                $(".cke_dialog_ui_vbox_child").css('height', height);
            },
            {
                onOk: function(e) {
                    //console.log('onok');
                    var context = ($("#"+domId).contents())[0];
                    var pathname = window.location.pathname;
                    // bugfix: get correct editor via this instead of global editor: var selection = editor.widgets.selected;
                    var selection = this["_"].editor.widgets.selected;
                    if (selection[0] != null) {
                        widget_scoped = selection[0];
                    }
                    //insert_the_image($("#f_url", context).val().replace(/file:/g, "image:"),
                    insert_the_media($("#f_url", context).val().replace(/file:/g, ""),
                                pathname+'/'+$("#f_url",context).val()+'?m=download',
                                editor,
                                $("#f_mime",context).val(),
                                widget_scoped,
                                $("#f_width",context).val(),
                                $("#f_height",context).val());
                }
            }
        );
        
        // Widget definition
        editor.widgets.add(pluginName, {
            defaults: {
                fileObjectPrettyLink: '',
                fileObjectName: '',
                fileObjectMimeType: '',
                playerSize: ''
            },
            template:
                '<span class="xowiki-image">' +
                    '<span class="xowiki-image-media-content"></span>' +
                    '<img/>'    +
                '</span>',

            parts: {
                content: 'span.xowiki-image-media-content',
                img: 'img'
            },
            allowedContent:
                'img;',

            dialog: pluginName,

            upcast: function( element ) {
                //returns true if element should be a widget
                //console.debug('upcast');
                //console.debug(element);
                return element.name == 'span' && element.hasClass( 'xowiki-image' );
            },

            init: function(w) {
                //console.debug('init');
            },
            data: function(w) {
                widget_scoped = w.sender;
            }
        });
        // Register the toolbar button.
        editor.ui.addButton( 'xowikiimage', {
            label : editor.lang.xowikiimage['insertImage'],
            command : pluginName,
            icon: this.path + 'images/image.gif'
        });


    }
} );

function insert_the_media(filename, src, editor, mimetype, widget, width, height) {
    var media_array = mimetype.split("/");
    switch(media_array[0]) {
        case 'image':
            widget.parts.img.setAttribute('src', src);
            widget.parts.img.setAttribute('alt', '.SELF./image:'+ filename);
            widget.parts.img.setAttribute('type', 'wikilink');
            break;
    }
}