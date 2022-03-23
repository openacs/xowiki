::xowiki::Package initialize -ad_doc {
  
  Import objects in XOTcl serializer format

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Aug 11, 2006
  @cvs-id $Id$
} -parameter {
  {-create_user_ids:integer 0}
  {-replace:integer 0}
  {-return_url:localurl ../}
  {-parent_id:object_id 0}
}

if {$parent_id ne 0} {
  set success 0
  try {
    ::xo::db::CrClass get_instance_from_db -item_id $parent_id
  } on ok {parentObj} {
    if {[$parentObj package_id] == $package_id} {
      set success 1
    }
  } on error {errorMsg} {
    ns_log warning "import.tcl sees invalid parent_id '$parent_id'"
  }
  if {!$success} {
    ad_return_complaint 1 "provided parent_id is invalid"
    ns_log notice STILL
    ad_script_abort
  }
}


set msg ""
ad_form \
    -name upload_form \
    -mode edit \
    -export {parent_id return_url} \
    -html { enctype multipart/form-data } \
    -form {
      {upload_file:file(file) {html {size 30}} {label "[_ xowiki.import_upload_file]"}}
      {create_user_ids:integer(radio),optional {options {{#acs-admin.Yes# 1} {#acs-admin.No# 0}}} {value 0}
        {label "[_ xowiki.import_create_user_ids]"}
        {help_text "[_ xowiki.import_create_user_ids_helptxt]"}
      }
      {replace:integer(radio),optional {options {{#acs-admin.Yes# 1} {#acs-admin.No# 0}}} {value 0}
        {label "[_ xowiki.import_replace]"}
        {help_text "[_ xowiki.import_replace_helptxt]"}
      }
      {ok_btn:text(submit) {label "[_ acs-templating.HTMLArea_SelectUploadBtn]"}
      }
    } \
    -on_submit {
      # check filename
      if {$upload_file eq ""} {
        template::form::set_error upload_form upload_file \
            [_ acs-templating.HTMLArea_SpecifyUploadFilename]
        break
      }

      set upload_tmpfile [template::util::file::get_property tmp_filename $upload_file]

      set file_looks_ok [util::file_content_check -type export -file ${upload_tmpfile}]
      if {!$file_looks_ok} {
        template::form::set_error upload_form upload_file \
            "The provided file is not in the export file format"
        break
      }
      
      set f [open $upload_tmpfile]
      #
      # If we do not set translation binary,
      # backslashes at the end of the lines might be lost
      #
      fconfigure $f -translation binary -encoding utf-8
      set content [read $f]; close $f

      foreach o [::xowiki::Page allinstances] {
        set preexists($o) 1
      }
      ad_try {
        namespace eval ::xo::import $content
      } on error {errorMsg} {
        ad_log error $errorMsg
        # cleanup all objects, that did not exist before
        foreach o [::xowiki::Page allinstances] {
          if {![info exists preexists($o)]} {
            if {[nsf::is object $o]} {$o destroy}
          }
        }
      } on ok {r} {
        set objects [list]
        foreach o [::xowiki::Page allinstances] {
          if {![info exists preexists($o)]} {lappend objects $o}
        }
        ns_log notice "objects to import: $objects"
        #::xotcl::Object msg parent_id=$parent_id
        ad_try {
          set msg [::$package_id import -replace $replace -create_user_ids $create_user_ids \
                       -parent_id $parent_id -objects $objects]
        } on error {errMsg} {
          ns_log Error "Error during import: $errMsg\nErrInfo: $::errorInfo"
          ::xotcl::Object msg "Error during import: $errMsg\nErrInfo: $::errorInfo"
          error $errMsg
        } finally {
          # Make sure objects have been cleaned up
          foreach o $objects {
            if {[nsf::is object $o]} {
              $o destroy
            }
          }
        }
      }
      namespace delete ::xo::import
    }


set title [_ xowiki.import_title]
set context .
ad_return_template

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
