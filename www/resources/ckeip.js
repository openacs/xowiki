/*

# CKEDITOR Edit-In Place jQuery Plugin.

# Created By Dave Earley.
# www.Dave-Earley.com
# Adapted by Michael Totschnig

*/

$.fn.ckeip = function (callback,options) {

  function load_ck (u_id) {
    var name = 'ckeip_e_' + u_id;
    var textarea = $('#' + name);
    textarea.ckeditor(callback,settings.ckeditor_config);
    CKEDITOR.instances[name].on('instanceReady',function(e) {settings.ckeditor_config.ready_callback});
    textarea.show();
    textarea.bind('destroy.ckeditor',settings.ckeditor_config.destroy_callback);
    $('#buttons_ckeip_' + u_id + '').show();
  }

  var defaults = {
    name: 'text',
    e_height: '1',
    data: {},
    e_hover_color: '#eeeeee',
    ckeditor_config: '',
    e_width: '50'
  };

  var settings = $.extend({}, defaults, options);
  
  return this.each(function () {
    var using_wrapper = false;
    var timeout;
    var delay = 500;

    // if the xowikiimage plugin is available we have to rewrite the wiki_image_links to image tags before loading
    if (settings.ckeditor_config.extraPlugins.indexOf("xowikiimage") != -1) {
        var eip_html = calc_wiki_image_links_to_image_tags(window.location.pathname, $(this).html());
        $(this).html(eip_html);
    } else {
        var eip_html = $(this).html();
    }

    if (eip_html == '&nbsp;') { eip_html = ''}
    var u_id = this.id;
    var div = $(this);
    div.addClass('ckeip');
    div.data('editing',false);
    var wrapper;
    if (settings.wrapper_class != '') {
      wrapper = div.closest('.'+settings.wrapper_class);
      if (wrapper.length == 0) {
        wrapper = div;
      } else {
        using_wrapper = true;
      }
    } else {
      wrapper = div;
    }
    
    // delete an already registered inplace ckedtior to ensure that the ckipeditors doesn't shown twice
    $('#ckeip_'+u_id).remove();
    
    $(this).before("<div id='ckeip_" + u_id + "'><textarea class='ckeip' style='display:none;' name='" + settings.name + "' id ='ckeip_e_" + u_id + "' cols='" + settings.e_width + "' rows='" + settings.e_height + "'  >" + eip_html + "</textarea><span style='display:none;' id='buttons_ckeip_" + u_id + "'><a href='#' id='close_ckeip_" + u_id + "'>Close</a></span></div>");

    wrapper.bind("click focusin",   function () {
      //we provide for the possibility that the element has been cloned
      //and changed id after having been initialized
      var div;
      var wrapper = this;
      if (using_wrapper) {
        div = $(wrapper).find('div.ckeip');
      } else {
        div = $(wrapper);
      }
      if (div.data('editing')) {return false}
      var u_id = div.attr('id');
      var textarea = $('#ckeip_e_' + u_id + '');
      if (!timeout) {
        timeout = setTimeout(function() {
          div.hide();
          div.data('editing',true);
          if (div.html().length > 0) {
            load_ck(u_id);
          } else {
          textarea.show();;
          textarea.focus();
          textarea.bind("focusout", function(ev) {
            var ckeip_html = textarea.val();
            if (ckeip_html == '') { ckeip_html = '&nbsp;'}
            div.html(ckeip_html);
            textarea.hide();
            textarea.unbind('focusout');
            div.show();
            div.data('editing',false);
            return false;
          });
          }
          timeout = null;
        }, delay);
      }
    });
    wrapper.bind("dblclick", function () {
      if (timeout) {
        // Clear the timeout since this is a double-click and we don't want
        // the 'click-only' code to run.
        clearTimeout(timeout);
        timeout = null;
      }
      var div;
      var wrapper = this;
      if (using_wrapper) {
        div = $(wrapper).find('div.ckeip');
      } else {
        div = $(wrapper);
      }
      if (div.data('editing')) {return false}
      var u_id = div.attr('id');
      div.hide();
      div.data('editing',true);
      load_ck(u_id);
    });

    wrapper.hover(function () {
      $(this).css({
        backgroundColor: settings.e_hover_color
      });
    }, function () {
      $(this).css({
        backgroundColor: ''
      });
    });
    $("#close_ckeip_" + u_id + "").click(function () {
      var wrapper;
      var u_id = this.id.substring(12);
      var textarea = $('#ckeip_e_' + u_id + '');
      var div = $('#' + u_id);
      var ckeip_html = textarea.val();
      if (ckeip_html == '') { ckeip_html = '&nbsp;'}
      div.html(ckeip_html);
      textarea.ckeditorGet().destroy();
      textarea.hide();
      $('#buttons_ckeip_' + u_id + '').hide();
      div.show();
      div.data('editing',false);
      return false;
    });
  });
};
