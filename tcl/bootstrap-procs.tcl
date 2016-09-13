::xo::library doc {
  bootstrap procs: provide some (initial) support for bootstrap library

  @creation-date 2014-04-14
  @author Günter Ernst
  @author Gustaf Neumann
  @cvs-id $Id$
}

::xo::library require menu-procs

namespace eval ::xowiki {
  # minimal implementation of Bootstrap "navbar"
  # currently only "dropdown" elements are supported within the navbar
  # TODO: add support to include: 
  # - forms 
  # - buttons
  # - text
  # - Non-nav links
  # - component alignment
  # - navbar positioning
  # - navbar inverting

  ::xo::tdom::Class create BootstrapNavbar \
      -superclass Menu \
      -parameter {
        {autorender false}
        {menubar}
        {containerClass "container"}
        {navbarClass "navbar navbar-default navbar-static-top"}
      }
  
  BootstrapNavbar instproc init {} {
    ::xo::Page requireJS "/resources/xowiki/jquery/jquery.min.js"
    set css [parameter::get_global_value -package_key xowiki -parameter BootstrapCSS] 
    set js  [parameter::get_global_value -package_key xowiki -parameter BootstrapJS]
    #
    # TODO: We should dynamically be able to determine the
    # directives. However, for the time being, the urls below are
    # trusted.
    #
    security::csp::require script-src maxcdn.bootstrapcdn.com
    security::csp::require style-src maxcdn.bootstrapcdn.com
    
    foreach url $css {::xo::Page requireCSS $url}
    foreach url $js  {::xo::Page requireJS  $url}
    next
  }

 
  BootstrapNavbar ad_instproc render {} {
    http://getbootstrap.com/components/#navbar
  } {
    html::nav -class [my navbarClass] -role "navigation" {
      #
      # Render the pull down menues
      # 
      html::div -class [my containerClass] {
        set rightMenuEntries {}
        foreach entry [my children] {
          if {[$entry istype ::xowiki::BootstrapNavbarDropdownMenu]} {
            $entry render
          } else {
            lappend rightMenuEntries $entry
          }
        }
        if {[llength $rightMenuEntries] > 0} {
          html::ul -class "nav navbar-nav navbar-right" {
            foreach entry $rightMenuEntries {
              $entry render
            }
          }
        }
      }
    }
  }              
  

  #
  # BootstrapNavbarDropdownMenu
  #  
  ::xo::tdom::Class create BootstrapNavbarDropdownMenu \
      -superclass Menu \
      -parameter {
        text
        header
        {brand false}
      }    

  BootstrapNavbarDropdownMenu ad_instproc render {} {doku} {
    # TODO: Add support for group-headers
    # get group header
    set group " "
    
    html::ul -class "nav navbar-nav" {
      html::li -class "dropdown" {
        set class "dropdown-toggle"
        if {[my brand]} {lappend class "navbar-brand"}
        html::a -href "\#" -class $class -data-toggle "dropdown" {
          html::t [my text] 
          html::b -class "caret"
        }
        html::ul -class "dropdown-menu" {
          foreach dropdownmenuitem [my children] {
            if {[$dropdownmenuitem set group] ne "" && [$dropdownmenuitem set group] ne $group } {
              if {$group ne " "} {
                html::li -class "divider"
              }
              set group [$dropdownmenuitem set group]
            }
            $dropdownmenuitem render
          }
        }
      }
    }
  }
  
  #
  # BootstrapNavbarDropdownMenuItem
  #  
  ::xo::tdom::Class create BootstrapNavbarDropdownMenuItem \
      -superclass MenuItem \
      -parameter {
        {href "#"}
        helptext
      }        
  
  BootstrapNavbarDropdownMenuItem ad_instproc render {} {doku} {
    html::li -class [expr {[my set href] eq "" ? "disabled": ""}] {
      html::a [my get_attributes target href title id] {
        html::t [my text]
      }
    }
    if {[my exists listener] && [my set listener] ne ""} {
      lassign [my listener] type body
      template::add_body_script -script [subst {
        document.getElementById('[my set id]').addEventListener('$type', function (event) {$body}, false);
      }]
    }
  }
  
  #
  # BootstrapNavbarDropzone
  #  
  ::xo::tdom::Class create BootstrapNavbarDropzone \
      -superclass MenuComponent \
      -parameter {
        {href "#"}
        text
        uploader
      }

  BootstrapNavbarDropzone instproc js {-uploadlink:required} {
    html::script -type "text/javascript" -nonce $::__csp_nonce {
      html::t [subst -nocommands {
        + function($) {
          'use strict';

          var dropZone = document.getElementById('drop-zone');
          var uploadForm = document.getElementById('js-upload-form');
          var progressBar = document.getElementById('dropzone-progress-bar');
          var uploadFileRunning = 0;
          
          var startUpload = function(files, csrf) {
            if (typeof files !== "undefined") {
               for (var i=0, l=files.length; i<l; i++) {
                 uploadFile(files[i], csrf);
               }
            } else {
              alert("No support for the File API in this web browser");
            }
          }

          var uploadFile = function(file, csrf) {
            var xhr;
            var formData = new FormData();
            var url = "$uploadlink" + "&name=" + file.name;
            xhr = new XMLHttpRequest();
            xhr.upload.addEventListener("progress", function (evt) {
              if (evt.lengthComputable) {
                // For multiple drop files, we should probably we should sum up the sizes.
                // However, this since the uploads are in parallel, this is already useful.
                progressBar.style.width = (evt.loaded / evt.total) * 100 + "%";
              } else {
                // No data to calculate on
              }
            }, false);
            xhr.addEventListener("load", function () {
              uploadFileRunning--;
              if (uploadFileRunning < 1) {
                window.location = window.location;
              }
            }, false);
            xhr.open("post", url, true);
            formData.append("upload", file);
            formData.append("__csrf_token", csrf);
            uploadFileRunning++;
            xhr.send(formData);
          }

          uploadForm.addEventListener('submit', function(e) {
            var input = document.getElementById('js-upload-files');
            var uploadFiles = input.files;
            var csrf = input.form.elements["__csrf_token"].value;
            e.preventDefault();
            startUpload(input.files, csrf)
          })

          dropZone.ondrop = function(e) {
            e.preventDefault();
            this.className = 'upload-drop-zone';
            var form = document.getElementById('js-upload-files').form;
            var csrf = form.elements["__csrf_token"].value;
            startUpload(e.dataTransfer.files, csrf)
          }

          dropZone.ondragover = function() {
            this.className = 'upload-drop-zone drop';
            return false;
          }

          dropZone.ondragleave = function() {
            this.className = 'upload-drop-zone';
            return false;
          }
        } (jQuery);
      }]
    }
  }

 
  BootstrapNavbarDropzone ad_instproc render {} {doku} {
    if {${:href} ni {"" "#"}} {
      html::li {
        html::form -method "post" -enctype "multipart/form-data" \
            -style "display: none;" \
            -id "js-upload-form" {
              html::div -class "form-inline" {
                html::div -class "form-group" {
                  html::input -type "file" -name {files[]} -id "js-upload-files" -multiple multiple
                }
                html::button -type "submit" -class "btn btn-sm btn-primary" -id "js-upload-submit" {
                  html::t ${:text}
                }
                ::html::CSRFToken
              }
            }
      }
      html::li {
        html::div -class "upload-drop-zone" -id "drop-zone" {
          html::t "DropZone"
          html::div -class "progress" {
            html::div -style "width: 0%;" -class "progress-bar" -id dropzone-progress-bar {
              html::span -class "sr-only" {html::t ""}
            }
          }
        }
      }
      my js -uploadlink ${:href}&uploader=${:uploader}
    }
  }

  #
  # BootstrapNavbarModeButton
  #  
  ::xo::tdom::Class create BootstrapNavbarModeButton \
      -superclass MenuItem \
      -parameter {
        {href "#"}
        {on:boolean false}
        {button}
        {CSSclass "checkbox-slider--b-flat"}
        {spanStyle "padding-left: 6px; padding-right: 6px;"}
      }        

  BootstrapNavbarModeButton instproc js {} {
    #
    # In the current implementation, the page refreshes itself after
    # successful mode change. This could be made configurable.
    #
    html::script -type "text/javascript" {
      html::t {
        function mode_button_ajax_submit(form) {
          $.ajax({
            type: "POST",
            url: $(form).attr('action'),
            data: $(form).serialize(),
            success: function(msg) { window.location = window.location; },
            error: function(){alert("failure");}
          });
        };
      }
    }
  }
  
  BootstrapNavbarModeButton ad_instproc render {} {doku} {
    html::li {
      html::form -class "form" -method "POST" -action ${:href} {
        html::div -class "checkbox ${:CSSclass}" {
          html::label -class "checkbox-inline" {
            set checked [expr {${:on} ? {-checked true} : ""}]
            html::input -class "debug form-control" -name "debug" -type "checkbox" {*}$checked \
                -onclick "mode_button_ajax_submit(this.form);"
            html::span -style ${:spanStyle} {html::t ${:text}}
            html::input -name "modebutton" -type "hidden" -value "${:button}"
          }
        }
      }
      my js
    }
  }

  # =======================================================
  # ::xo::library doc {
  #   ... styling for bootstrap menubar ...
  # }
  #
  # ::xo::db::require package xowiki
  # ::xo::library require -package xowiki bootstrap-procs
  #
  # namespace eval ::mystyle {
  #   #
  #   # Define mixins for the classes. One can overload e.g. parameters
  #   # via the constructor, or one can e.g. overload the full render
  #   # method.
  #   #
  #   ::xo::tdom::Class create ::mystyle::BootstrapNavbarModeButton \
  #       -superclass ::xowiki::MenuItem
  #
  #   ::xowiki::BootstrapNavbarModeButton instproc init args {
  #     set :CSSclass checkbox-slider--a
  #     set :spanStyle "padding-left: 4ex; padding-right: 2ex;"
  #     next
  #   }
  #   ::xowiki::BootstrapNavbarModeButton instmixin ::mystyle::BootstrapNavbarModeButton
  # }
  #
  # ::xo::library source_dependent
  # =======================================================
  
  
  # --------------------------------------------------------------------------
  # Render MenuBar in bootstap fashion
  # --------------------------------------------------------------------------
  ::xowiki::MenuBar instproc render-bootstrap {} {
    set dict [my content]
    set mb [::xowiki::BootstrapNavbar \
                -id [my get_prop $dict id] \
                -menubar [self] {
                  foreach {att value} $dict {
                    if {$att eq "id"} continue
                    switch [my get_prop $value kind] {
                      "DropZone" {
                        ::xowiki::BootstrapNavbarDropzone \
                            -text [my get_prop $value label] \
                            -href [my get_prop $value url] \
                            -uploader [my get_prop $value uploader] {}
                      }
                      "ModeButton" {
                        template::head::add_css -href "/resources/xotcl-core/titatoggle/titatoggle-dist.css"

                        ::xowiki::BootstrapNavbarModeButton \
                            -text [my get_prop $value label] \
                            -href [my get_prop $value url] \
                            -button [my get_prop $value button admin] \
                            -on [my get_prop $value on] {}
                      }
                      "MenuButton" {
                        # render erverthing as a dropdown
                        ::xowiki::BootstrapNavbarDropdownMenu \
                            -text [my get_prop $value label] {
                              #ns_log notice "... dropdown att $att menu $value"
                              foreach {item_att item} $value {
                                if {[string match {[a-z]*} $item_att]} continue
                                ::xowiki::BootstrapNavbarDropdownMenuItem \
                                    -text [my get_prop $item label] \
                                    -href [my get_prop $item url] \
                                    -group [my get_prop $item group] \
                                    -listener [my get_prop $item listener] \
                                    {}
                              }
                            }
                      }
                    }
                  }}]
    #ns_log notice "call menubar asHTML"
    return [$mb asHTML]
  }
}

###############################################################################
#   Bootstrap table
###############################################################################

# TODO Allow renderers from other namespaces in 30-widget-procs

namespace eval ::xo::Table {

  Class create ::xowiki::BootstrapTable \
      -superclass ::xo::Table \
      -parameter {
        skin
      }

  ::xowiki::BootstrapTable instproc init {} {
    set trn_mixin [expr {[lang::util::translator_mode_p] ?"::xo::TRN-Mode" : ""}]
    my render_with BootstrapTableRenderer $trn_mixin
    next
  }
  
  Class create BootstrapTableRenderer \
      -superclass TABLE3 \
      -instproc init_renderer {} {
        next
        my set css.table-class "table table-striped"
        my set css.tr.even-class even
        my set css.tr.odd-class odd
        my set id [::xowiki::Includelet js_name [::xowiki::Includelet html_id [self]]]
      }

  BootstrapTableRenderer instproc render-body {} {
    html::thead {
      html::tr -class list-header {
        foreach o [[self]::__columns children] {
          if {[$o hide]} continue
          $o render
        }
      }
    }
    set children [my children]
    html::tbody {
      foreach line [my children] {
        html::tr -class [expr {[my incr __rowcount]%2 ? [my set css.tr.odd-class] : [my set css.tr.even-class] }] {
          foreach field [[self]::__columns children] {
            if {[$field hide]} continue
            if {[$field istype HiddenField]} continue
            html::td  [concat [list class list] [$field html]] { 
              $field render-data $line
            }
          }
        }
      }
    }
  }

  BootstrapTableRenderer instproc render-bulkactions {} {
    set bulkactions [[self]::__bulkactions children]
    html::div -class "btn-group" -role group -aria-label "Bulk actions" {
      html::t "Bulk-Actions:"
      set bulkaction_container [[lindex $bulkactions 0] set __parent]
      set name [$bulkaction_container set __identifier]

      foreach ba $bulkactions {
        set id [::xowiki::Includelet html_id $ba]
        html::ul -class compact {
          html::li {
            # For some reason, btn-secondary seems not to be available
            # for the "a" tag, so we set the border-color manually.
            html::a -class "btn btn-secondary" -rule button \
                -title [$ba tooltip] -href # \
                -style "border-color: #ccc;" \
                -id $id {
                  html::t [$ba label]
                }
          }
        }
        template::add_body_script -script [subst {
          document.getElementById('$id').addEventListener('click', function (event) {
            acs_ListBulkActionClick('$name','[$ba url]');
          }, false);
        }]
      }
    }
  }

  BootstrapTableRenderer instproc render {} {
    ::xo::Page requireCSS "//maxcdn.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css"
    security::csp::require style-src maxcdn.bootstrapcdn.com
    security::csp::require font-src maxcdn.bootstrapcdn.com
    
    if {![my isobject [self]::__actions]} {my actions {}}
    if {![my isobject [self]::__bulkactions]} {my __bulkactions {}}
    set bulkactions [[self]::__bulkactions children]
    if {[llength $bulkactions]>0} {
      set name [[self]::__bulkactions set __identifier]
    } else {
      set name [::xowiki::Includelet js_name [self]]
    }

    html::div -id [my set id]_wrapper -class "table-responsive" {
      html::form -name $name -id $name -method POST { 
        html::div -id [my set id]_container {
          html::table -id [my set id] -class [my set css.table-class] {
            my render-actions
            my render-body
          }
          if {[llength $bulkactions]>0} { my render-bulkactions }
        }
      }
    }
  }


  #Class create BootstrapTableRenderer::AnchorField -superclass TABLE::AnchorField

  Class create BootstrapTableRenderer::AnchorField \
      -superclass TABLE::Field \
      -ad_doc "
            In addition to the standard TableWidget's AnchorField, we also allow the attributes
            <ul>
                <li>onclick
                <li>target
            </ul>
        " \
      -instproc render-data {line} {
        set __name [my name]
        if {[$line exists $__name.href] &&
            [set href [$line set $__name.href]] ne ""} {
          # use the CSS class rather from the Field than not the line
          my instvar CSSclass
          $line instvar   [list $__name.title title] \
              [list $__name.target target] \
              [list $__name.onclick onclick] 
          html::a [my get_local_attributes href title {CSSclass class} target onclick] {
            return "[next]"
          }
        }
        next
      }

  Class create BootstrapTableRenderer::Action -superclass TABLE::Action
  Class create BootstrapTableRenderer::Field -superclass TABLE::Field
  Class create BootstrapTableRenderer::HiddenField -superclass TABLE::HiddenField
  Class create BootstrapTableRenderer::ImageField -superclass TABLE::ImageField
  Class create BootstrapTableRenderer::ImageAnchorField -superclass TABLE::ImageAnchorField
  Class create BootstrapTableRenderer::BulkAction -superclass TABLE::BulkAction
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
