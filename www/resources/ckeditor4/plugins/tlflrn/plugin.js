
var tlflrn_dialog = $("<div class='tlflrn_dialog'>X</div>");

tlflrn_dialog.dialog({
    modal: true, 
    width: '715px', 
    autoOpen: false, 
    zIndex: 10000
});

var interaction_types = [
  "choice",
  "textEntry",
  "inlineChoice",
  "gapMatch",
  "extendedText",
  "order",
  "associate"
];

CKEDITOR.plugins.add( 'tlflrn', {
    requires: ['richcombo'],
    lang : [ 'en', 'de' ],

    init : function( editor ) {
        var config = editor.config;
        var pluginName = 'tlflrn';
        var name, interaction, title;
            editor.ui.addRichCombo( 'tlflrn',
            {
             label : editor.lang.tlflrn['menuLabel'],
             title : editor.lang.tlflrn['menuTitle'],
             className : 'cke_interactions',
             multiSelect : false,
             panel :
             {
                css : [ config.contentsCss, CKEDITOR.getUrl( editor.skinPath + 'editor.css' ) ]
             },
             init : function()
             {
                this.startGroup( editor.lang.tlflrn['menuLabel'] );
                // this.add('value', 'drop_text', 'drop_label');
                for (var i=0; i<interaction_types.length; i++) {
                  name = interaction_types[i];
                  interaction = editor.lang.tlflrn[name];
                  title = editor.lang.tlflrn.insertInteraction.replace( /%/, interaction )
                  this.add(name,interaction,title);
                  //this prevents the title of the select box to be set to the clicked on button
                  this.setValue =  function( value, text ) { this._.value = value; };
                }
                //is commit needed?
                //this.commit();
             },
             onClick : function( value )
             {
                insert_qti(editor,value);
             }
             });                        
        
    
        // // Register the toolbar button.
        // editor.ui.addButton( 'tlflrn', {
        //     label : editor.lang.tlflrn['insertImage'],
        //     command : pluginName,
        //     icon: this.path + 'images/image.gif'
        // });
    }
} );




function randomXoQtiID() {
  var chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXTZabcdefghiklmnopqrstuvwxyz";
  var id = 'xoqti_';
  for (var i=0; i<8; i++) {
      var rnum = Math.floor(Math.random() * chars.length);
      id += chars.substring(rnum,rnum+1);
  }
  if ($("#"+id).length == 0) { return(id);} else { return randomXoQtiID(); };
}



function new_Interaction(editor, id, type) {
    console.log(editor + '----' + id + '----' + type);
  type = type +'Interaction';
  var title=editor.lang.tlflrn[type];
  tlflrn_dialog.load('/global/tlf-lrn-core/ckeditor-excs/',{m:"create-new",item_new:id, type:type},
    function() { 
                 tlflrn_dialog.dialog({title:title});
                 tlflrn_dialog.dialog("open");
                 tlflrn_dialog.find('input').keypress(function(e) {
                   if ((e.which && e.which == 13) || (e.keyCode && e.keyCode == 13)) {
                     return false;
                   }
                 });
                 tlflrn_dialog.find("form").submit(function() {
                   calc_image_tags_to_wiki_image_links(this);
                   if (validateInteraction(editor,this,type)) {
                     submitInteraction(this, editor);
                   }
                   return false;
                 });
    });
}

function insert_qti(editor, type) {
  editor.focus();
  editor.fire( 'saveSnapshot' );
  var id=randomXoQtiID();
  new_Interaction(editor, id, type);
  editor.fire( 'saveSnapshot' );
}
