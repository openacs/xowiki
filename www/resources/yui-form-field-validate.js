/*
 * A simple form field validator based on YUI
 *
 * Gustaf Neumann                      fecit Nov 2009
 */

YAHOO.namespace('xo_form_field_validate');

YAHOO.xo_form_field_validate = {
    current_url: "",
    currentID: "",
    ids: new Array(),

    init: function() {
       // console.log("init");
       var ids = YAHOO.xo_form_field_validate.ids;
       for (var i=0; i<ids.length; i++) {
          var el =  document.getElementById(ids[i]);
          // when we use onblur, changing the focus manually can lead
          // to an infinite loop; so we use for the time being onChange instead of onBlur.
          YAHOO.util.Event.on(el, "change", YAHOO.xo_form_field_validate.validate);
          //YAHOO.util.Event.onBlur(el, YAHOO.xo_form_field_validate.validate, this, false);
       }
    },

    add: function(id, package_url) {
       // console.log('adding listener for ' + id);
       this.ids.push(id);
       this.package_url = package_url;
    },

    validate: function(e) {
       //console.log('validate ');
       this.callback = {

           failure: function(o) {
             if (o.status == 406) {
               // console.log('Validation not successful')
               //console.info(this);
               var inputID = this.currentID;
               var errorEl = YAHOO.util.Dom.get(inputID + "-error");
               var inputEl = YAHOO.util.Dom.get(inputID);
               if (errorEl == undefined) {
                 var n = document.createElement("div");
                 n.innerHTML = o.responseText;
                 n.id = inputID + "-error";
                 YAHOO.util.Dom.insertAfter(n, inputEl);
                 if (YAHOO.util.Dom.hasClass(inputEl.parentNode,"form-widget")) {
                   //console.log("parent has class form-widget, replace");
                   YAHOO.util.Dom.replaceClass(inputEl.parentNode,"form-widget","form-widget-error");
                 } else {
                   //console.log("parent has no class form-widget, add");
                   YAHOO.util.Dom.addClass(inputEl.parentNode,"form-widget-error");
                 }
               } else {
                 errorEl.innerHTML = o.responseText;
               }
               inputEl.focus();
             }
           },

           success: function(o) {
             // console.info(o);

             // There seems no way to handle redirects
             // (301 or 302) in the asyncrequest. Since we know valid
             // results (just the "OK"), everything else must be a
             // redirect. We could be brutal and display the returned
             // page, but not sure, if this would be desireable either.
             if (o.status == 200 && o.getResponseHeader["Content-Length"] > 10) {
               // there must have happened a redirect
               console.info(o);
               alert("Refresh your login and redo update");
               //window.location.href = this.package_url 
               //   + "?refresh-login&return_url=" 
               //   + escape(this.current_url);
             } else {
               var inputID = this.currentID;
               var errorEl = YAHOO.util.Dom.get(inputID + "-error");
               var inputEl = YAHOO.util.Dom.get(inputID);
               if (errorEl != undefined) {
                 errorEl.parentNode.removeChild(errorEl);  
               }
               if (YAHOO.util.Dom.hasClass(inputEl.parentNode,"form-widget-error") &&
                   inputEl.parentNode.class != "form-widget-error") {
                 YAHOO.util.Dom.replaceClass(inputEl.parentNode,"form-widget-error","form-widget");
               } else {
                 YAHOO.util.Dom.removeClass(inputEl.parentNode,"form-widget-error");
               }
             }
         },

         scope: YAHOO.xo_form_field_validate
       }

       var url = window.location.href.replace(/[?].*/,"") + '?m=validate-attribute';
       var post_query = e.target.name + '=' + escape(e.target.value);
       YAHOO.xo_form_field_validate.current_url = url + '&' + post_query;
       YAHOO.xo_form_field_validate.currentID = e.target.id;
       //console.log(url);
       //console.log(post_query);
       YAHOO.util.Connect.asyncRequest('POST', url, this.callback, post_query);
       return 1;
  }

};

YAHOO.util.Event.onDOMReady(YAHOO.xo_form_field_validate.init); 

