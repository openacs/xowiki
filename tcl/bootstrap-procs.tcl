::xo::library doc {
  bootstrap procs: provide some (initial) support for bootstrap library

  @creation-date 2014-04-14
  @author Günter Ernst
  @author Gustaf Neumann
  @cvs-id $Id$
}

::xo::library require menu-procs
::xo::library require -package xotcl-core 30-widget-procs

namespace eval ::xowiki {
  #
  # Minimal implementation of Bootstrap "navbar"
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
        {containerClass "container-fluid px-0"}
        {navbarClass "navbar navbar-expand-lg navbar-default navbar-static-top mx-2 p-0"}
      }

  BootstrapNavbar instproc init {} {
    ::xo::Page requireJS urn:ad:js:jquery
    ::xowiki::CSS require_toolkit -css -js
    next
  }


  BootstrapNavbar ad_instproc render {} {
    http://getbootstrap.com/components/#navbar
  } {
    html::nav -class [xowiki::CSS classes ${:navbarClass}] -role "navigation" -style "background-color: #f8f9fa;" {
      #
      # Render the pull down menus
      #
      html::div -class ${:containerClass} {
        set rightMenuEntries {}
        foreach entry [:children] {
          if {[$entry istype ::xowiki::BootstrapNavbarDropdownMenu]} {
            $entry render
          } else {
            lappend rightMenuEntries $entry
          }
        }
        if {[llength $rightMenuEntries] > 0} {
          html::ul -class "nav navbar-nav [::xowiki::CSS class navbar-right]" {
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

    html::ul -class "nav navbar-nav px-3" {
      html::li -class "nav-item dropdown" {
        set class "nav-link dropdown-toggle"
        if {${:brand}} {
          lappend class "navbar-brand"
        }
        set data_attribute [expr {[::xowiki::CSS toolkit] eq "bootstrap5" ? "data-bs" : "data"}]
        html::a -href "\#" -class $class -$data_attribute-toggle "dropdown" {
          html::t ${:text}
          if {[xowiki::CSS toolkit] eq "bootstrap"} {
            html::b -class "caret"
          }
        }
        html::ul -class "dropdown-menu" {
          foreach dropdownmenuitem [:children] {
            if {[$dropdownmenuitem set group] ne ""
                && [$dropdownmenuitem set group] ne $group
              } {
              if {$group ne " "} {
                html::li -class "divider dropdown-divider"
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
    html::li -class [expr {${:href} eq "" ? "nav-item disabled": "nav-item"}] {
      set :CSSclass dropdown-item
      html::a [:get_attributes target href title id {CSSclass class}] {
        html::t ${:text}
      }
    }
    html::t \n
    if {[info exists :listener] && ${:listener} ne ""} {
      lassign ${:listener} type body
      template::add_event_listener -event $type -id ${:id} \
          -preventdefault=false -script $body
    }
  }

  #
  # BootstrapNavbarDropzone
  #
  ::xo::tdom::Class create BootstrapNavbarDropzone \
      -superclass MenuComponent \
      -parameter {
        {label "DropZone"}
        {href "#"}
        {text ""}
        {disposition File}
        {file_name_prefix ""}
      } \
      -ad_doc {

        Dropzone widget for drag and drop of files, e.g. in the
        menubar.  The widget provides added support for updating the
        current page with feedback of the dropped files.

        @param href URL for POST request
        @param label Text to be displayed at the place where files are
               dropped to
        @param file_name_prefix prefix for files being uploaded
               (used e.g. by the online exam).
        @param disposition define, what happens after the file was
               uploaded, e.g. whether the content has to be
               transformed, stored and displayed later.
      }

  BootstrapNavbarDropzone instproc js {} {
    html::script -type "text/javascript" -nonce [security::csp::nonce] {
      html::t {
        + function($) {
          'use strict';

          var dropZone = document.getElementById('drop-zone');
          var uploadForm = document.getElementById('js-upload-form');
          var progressBar = document.getElementById('dropzone-progress-bar');
          var dropZoneResponse = document.getElementById('thumbnail-files-wrapper');
          var uploadFileRunning = 0;
          var uploadFilesStatus = [];
          var uploadFilesResponse = [];

          var startUpload = function(files, disposition, url, prefix, csrf) {
            //console.log("files " + files + " dispo '"+ disposition + "' url " + url + " prefix " + prefix);
            if (typeof files !== "undefined") {
              for (var i=0, l=files.length; i<l; i++) {
                 // Send the file as multiple single requests and
                 // not as a single post containing all entries. This
                 // gives users with older NaviServers or AOLserver the chance
                 // drop multiple files.
                 uploadFile(files[i], disposition, url, prefix, csrf);
               }

            } else {
              alert("No support for the File API in this web browser");
            }
          }

          var uploadFile = function(file, disposition, url, prefix, csrf) {
            var xhr;
            var formData = new FormData();
            var fullName = (prefix == "" ? file.name : prefix + '/' + file.name);
            var fullUrl = url
            + "&disposition=" + encodeURIComponent(disposition)
            + "&name=" + encodeURIComponent(fullName);

            xhr = new XMLHttpRequest();
            xhr.upload.addEventListener("progress", function (evt) {
              if (evt.lengthComputable) {

                // For multiple drop files, we should probably we
                // should sum up the sizes.  However, since the
                // uploads are in parallel, this is already useful.

                progressBar.style.width = (evt.loaded / evt.total) * 100 + "%";
              } else {
                // No data to calculate on
              }
            }, false);
            xhr.addEventListener("load", function (event) {
              uploadFileRunning--;
              uploadFilesStatus.push(event.currentTarget.status);
              uploadFilesResponse.push(event.currentTarget.response);
              //console.log("ended with status " + event.currentTarget.status);
              //console.log("running: " + uploadFileRunning);
              if (dropZoneResponse) {

                // We have a dropzone response and update this in the
                // web page.

                dropZoneResponse.innerHTML = uploadFilesResponse[uploadFilesResponse.length-1];
                dropZoneResponse.querySelectorAll('.thumbnail-file').forEach(el => thumbnail_files_setup(el));
              }
              if (uploadFileRunning < 1) {
                if (dropZoneResponse) {

                  // We are done with all uploads. When the response is
                  // provided, it was updated above already in the web
                  // page, but we have still to reset the progress bar
                  // to indicate that we are done.

                  progressBar.style.width = '0%';

                } else {
                  // Reload the page to trigger a refresh
                  location.reload(true);
                }
              }
            }, false);
            xhr.open("post", fullUrl, true);
            formData.append("upload", file);
            formData.append("__csrf_token", csrf);
            uploadFileRunning++;
            xhr.send(formData);
          }

          uploadForm.addEventListener('submit', function(e) {
            //
            // Input handler for classical form submit
            //
            var input = document.getElementById('js-upload-files');
            var uploadFiles = input.files;
            var csrf = input.form.elements["__csrf_token"].value;
            e.preventDefault();
            //console.log("Submit handler");
            startUpload(input.files,
                        input.dataset.disposition ?? 'File',
                        input.dataset.url,
                        input.dataset.file_name_prefix ?? '',
                        csrf);
          })

          dropZone.ondrop = function(e) {
            //
            // Input handler for drag & drop
            //
            e.preventDefault();
            this.className = 'upload-drop-zone';
            var form = document.getElementById('js-upload-files').form;
            var csrf = form.elements["__csrf_token"].value;
            var input = document.getElementById('js-upload-files');
            //console.log("Drop handler");
            startUpload(e.dataTransfer.files,
                        input.dataset.disposition ?? 'File',
                        input.dataset.url,
                        input.dataset.file_name_prefix ?? '',
                        csrf);
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
      }
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
                  html::input \
                      -type "file" \
                      -name {files[]} \
                      -id "js-upload-files" \
                      -data-file_name_prefix ${:file_name_prefix} \
                      -data-url ${:href} \
                      -data-disposition ${:disposition} \
                      -multiple multiple
                }
                html::button -type "submit" -class "btn btn-sm btn-primary" -id "js-upload-submit" {
                  html::t ${:text}
                }
                ::html::CSRFToken
              }
            }
        html::div -class "upload-drop-zone" -id "drop-zone" {
          html::span {html::t ${:label}}
          html::div -class "progress" {
            html::div -style "width: 0%;" -class "progress-bar" -id dropzone-progress-bar {
              html::span -class "sr-only" {html::t ""}
            }
          }
        }
      }
      :js
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
    html::script -type "text/javascript" -nonce [security::csp::nonce] {
      html::t {
        function mode_button_ajax_submit(form) {
          $.ajax({
            type: "POST",
            url: $(form).attr('action'),
            data: $(form).serialize(),
            success: function(msg) { location.reload(true); },
            error: function(){alert("failure");}
          });
        };
      }
      html t [subst {
        document.getElementById('${:id}').addEventListener('click', function (event) {
          mode_button_ajax_submit(this.form);
        });
      }]
    }
  }

  BootstrapNavbarModeButton instproc render {} {
    html::li {
      html::form -class "form" -method "POST" -action ${:href} {
        html::div -class "checkbox ${:CSSclass}" {
          html::label -class "checkbox-inline" {
            set checked [expr {${:on} ? {-checked true} : ""}]
            html::input -id ${:id} -class "debug form-control" -name "debug" -type "checkbox" {*}$checked
            html::span -style ${:spanStyle} {html::t ${:text}}
            html::input -name "modebutton" -type "hidden" -value "${:button}"
          }
        }
      }
      :js
    }
  }

  ::xo::tdom::Class create BootstrapCollapseButton \
      -parameter {
        {id:required}
        {toggle:required}
        {direction:required}
        {label:required}
      }

  BootstrapCollapseButton instproc render {} {
    switch [::xowiki::CSS toolkit] {
      "bootstrap" {
        template::add_script -src urn:ad:js:bootstrap3
        ::html::button -type button -class "btn btn-xs" -data-toggle ${:toggle} -data-target "#${:id}" {
          ::html::span -class "glyphicon glyphicon-chevron-${:direction}" {::html::t ${:label}}
        }
      }
      "bootstrap5" {
        template::add_script -src urn:ad:js:bootstrap5
        ::html::button -type button -class "btn btn-sm" -data-bs-toggle ${:toggle} -data-bs-target "#${:id}" {
          ::html::i -class "bi bi-chevron-${:direction}" {::html::t ${:label}}
        }
      }
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
  # Render MenuBar in bootstrap fashion
  # --------------------------------------------------------------------------
  ::xowiki::MenuBar instproc render-bootstrap {} {
    set dict [:content]
    set mb [::xowiki::BootstrapNavbar \
                -id [:get_prop $dict id] \
                -menubar [self] {
                  foreach {att value} $dict {
                    if {$att eq "id"} continue
                    switch [:get_prop $value kind] {
                      "DropZone" {
                        ::xowiki::BootstrapNavbarDropzone \
                            -text [:get_prop $value label] \
                            -href [:get_prop $value url] \
                            -disposition [:get_prop $value disposition File] {}
                      }
                      "ModeButton" {
                        template::head::add_css \
                            -href "/resources/xotcl-core/titatoggle/titatoggle-dist.css"

                        ::xowiki::BootstrapNavbarModeButton \
                            -text [:get_prop $value label] \
                            -href [:get_prop $value url] \
                            -button [:get_prop $value button admin] \
                            -on [:get_prop $value on] {}
                      }
                      "MenuButton" {
                        # render erverthing as a dropdown
                        ::xowiki::BootstrapNavbarDropdownMenu \
                            -text [:get_prop $value label] {
                              #ns_log notice "... dropdown att $att menu $value"
                              foreach {item_att item} $value {
                                if {[string match {[a-z]*} $item_att]} continue
                                ::xowiki::BootstrapNavbarDropdownMenuItem \
                                    -text [:get_prop $item label] \
                                    -href [:get_prop $item url] \
                                    -group [:get_prop $item group] \
                                    -listener [:get_prop $item listener] \
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
    :render_with BootstrapTableRenderer $trn_mixin
    next
  }

  Class create BootstrapTableRenderer \
      -superclass TABLE3 \
      -instproc init_renderer {} {
        next
        set :css.table-class "table table-striped"
        set :css.tr.even-class "align-middle"
        set :css.tr.odd-class "align-middle"
        set :id [::xowiki::Includelet js_name [::xowiki::Includelet html_id [self]]]
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
    ad_try {
      set children [:children]
    } on error {errorMsg} {
      html::div -class "alert alert-danger" {
        html::span -class danger {
          html::t $errorMsg
        }
      }
      return
    }
    html::tbody {
      foreach line [:children] {
        html::tr -class [expr {[incr :__rowcount]%2 ? ${:css.tr.odd-class} : ${:css.tr.even-class} }] {
          foreach field [[self]::__columns children] {
            if {[$field hide]} continue
            if {[$field istype HiddenField]} continue
            set CSSclass [list "list" {*}[$field CSSclass]]
            html::td [concat [list class $CSSclass] [$field html]] {
              $field render-data $line
            }
          }
        }
      }
    }
  }

  BootstrapTableRenderer instproc render-bulkactions {} {
    set bulkactions [[self]::__bulkactions children]
    if {[llength $bulkactions] > 0} {
      html::div -class "btn-group align-items-center" -role group -aria-label "Bulk actions" {
        html::t "#xotcl-core.Bulk_actions#:"
        set bulkaction_container [[lindex $bulkactions 0] set __parent]
        set name [$bulkaction_container set __identifier]

        foreach bulk_action $bulkactions {
          set id [::xowiki::Includelet html_id $bulk_action]
          html::ul -class compact {
            html::li {
              html::a -class [::xowiki::CSS class bulk-action] -rule button \
                  -title [$bulk_action tooltip] -href # \
                  -id $id {
                    html::t [$bulk_action label]
                  }
            }
          }
          set script [subst {
            acs_ListBulkActionClick("$name","[$bulk_action url]");
          }]
          if {[$bulk_action confirm_message] ne ""} {
            set script [subst {
              if (confirm('[$bulk_action confirm_message]')) {
                $script
              }
            }]
          }
          template::add_event_listener \
              -id $id \
              -preventdefault=false \
              -script $script
        }
      }
    }
  }

  BootstrapTableRenderer instproc render {} {
    ::xowiki::CSS require_toolkit -css

    if {![nsf::is object [self]::__actions]} {:actions {}}
    if {![nsf::is object [self]::__bulkactions]} {:__bulkactions {}}
    set bulkactions [[self]::__bulkactions children]
    if {[[self]::__bulkactions exists __identifier]} {
      set name [[self]::__bulkactions set __identifier]
      html::div -id ${:id}_wrapper -class "table-responsive" {
        html::form -name $name -id $name -method POST {
          html::div -id ${:id}_container {
            html::table -id ${:id} -class ${:css.table-class} {
              :render-actions
              :render-body
            }
            :render-bulkactions
          }
        }
      }
    } else {
      set name [::xowiki::Includelet js_name [self]]
      #
      # Nesting forms inside an xowf page will place the action
      # buttons at the wrong place!
      #
      html::div -id ${:id}_wrapper -class "table-responsive" {
        html::div -id ${:id}_container {
          html::table -id ${:id} -class ${:css.table-class} {
            :render-actions
            :render-body
          }
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
        set __name ${:name}
        if {[$line exists $__name.href]
            && [set href [$line set $__name.href]] ne ""
          } {
          $line instvar [list $__name.title title] [list $__name.target target]
          if {[$line exists $__name.onclick]} {
            set id [::xowiki::Includelet html_id $line]
            template::add_event_listener \
                -id $id \
                -script "[$line set $__name.onclick];"
          }
          #
          # The default class is from the field definition. Append to this value
          # the class coming from the entry line.
          #
          set CSSclass ${:CSSclass}
          if {[$line exists $__name.CSSclass]} {
            set lineCSSclass [$line set $__name.CSSclass]
            if {$lineCSSclass ne ""} {
              append CSSclass " " $lineCSSclass
            }
          }
          html::a [:get_local_attributes href title {CSSclass class} target id] {
            return [next]
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

namespace eval ::xowiki::bootstrap {

  ad_proc ::xowiki::bootstrap::card {
    -title:required
    -body:required
  } {
    Render a Bootstrap Card.

    @return HTML
  } {
    return [ns_trim -delimiter | [subst {
      |<div class="[xowiki::CSS class card]">
      |  <div class="[xowiki::CSS class card-header]">$title</div>
      |  <div class="[xowiki::CSS class card-body]">$body</div>
      |</div>
    }]]
  }

  ad_proc ::xowiki::bootstrap::icon {
    -name:required
    -style
    -CSSclass
  } {
    Render a Bootstrap Icon.

    @return HTML
  } {
    #<span class="glyphicon glyphicon-cog" aria-hidden="true" style="float: right;"></span>
    set name [xowiki::CSS class $name]
    set styleAtt [expr {[info exists style] ? "style='$style'" : ""}]
    set CSSclass [expr {[info exists CSSclass] ? " $CSSclass" : ""}]
    switch [::xowiki::CSS toolkit] {
      "bootstrap" {
        return [subst {<span class="glyphicon glyphicon-$name$CSSclass" aria-hidden="true" $styleAtt></span>}]
      }
      default {
        return [subst {<i class="bi bi-$name$CSSclass" aria-hidden="true" $styleAtt></i>}]
      }
    }
  }


  ad_proc ::xowiki::bootstrap::modal_dialog {
    -id:required
    -title:required
    {-subtitle ""}
    -body:required
  } {
    Generic modal dialog wrapper.
    @param id
    @param title HTML markup for the modal title (can contain tags)
    @param subtitle HTML markup for the modal subtitle (can contain tags)
    @param body HTML markup for the modal body (can contain tags)

    @return HTML markup
  } {
    if {$subtitle ne ""} {
      set subtitle [subst {<p class="modal-subtitle">$subtitle</p>}]
    }
    if {[::xowiki::CSS toolkit] eq "bootstrap5"} {
      set data_attribute "data-bs"
      ::security::csp::require img-src data:
      set close_button_label ""
      set before_close  "<h4 class='modal-title' id='configurationModalTitle'>$title</h4>"
      set after_close  ""
    } else {
      set data_attribute "data"
      set close_button_label {<span aria-hidden="true">&#215;</span>}
      set before_close  ""
      set after_close  "<h4 class='modal-title' id='configurationModalTitle'>$title</h4>"
    }

    return [ns_trim -delimiter | [subst {
      |<div class="modal fade" id="$id" tabindex="-1" role="dialog"
      |     aria-labelledby="$id-label" aria-hidden="true">
      |  <div class="modal-dialog" role="document">
      |    <div class="modal-content">
      |      <div class="modal-header">
      |        $before_close<button type="button" class="[xowiki::CSS class close]"
      |           $data_attribute-dismiss="modal" aria-label="Close">$close_button_label
      |        </button>$after_close
      |      </div>
      |      <div class="modal-body">$subtitle
      |        <form class="form-horizontal" id="configuration-form" role="form" action="#" method="post">
      |        $body
      |        </form>
      |      </div>
      |      <div class="modal-footer">
      |        <button type="button" class="btn [::xowiki::CSS class btn-default]"
      |                $data_attribute-dismiss="modal">#acs-kernel.common_Cancel#
      |        </button>
      |        <button id="$id-confirm" type="button" class="btn btn-primary confirm"
      |                $data_attribute-dismiss="modal">#acs-subsite.Confirm#
      |        </button>
      |      </div>
      |    </div>
      |  </div>
      |</div>
    }]]
  }



  ad_proc ::xowiki::bootstrap::modal_dialog_popup_button {
    -target:required
    -label:required
    {-title ""}
    {-CSSclass ""}
  } {
    Generic modal dialog wrapper.
    @param target ID of the target modal dialog
    @param title title for the anchor (help popup), plain text
    @param label HTML markup for the modal popup label (can contain tags)

    @return HTML markup
  } {
    if {[::xowiki::CSS toolkit] eq "bootstrap5"} {
      set data_attribute "data-bs"
    } else {
      set data_attribute "data"
    }
    return [ns_trim -delimiter | [subst {
      |<a class="$CSSclass" href="#" title="$title"
      |  $data_attribute-toggle="modal" $data_attribute-target='#$target'>
      |  $label
      |</a>
    }]]
  }
}



::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
