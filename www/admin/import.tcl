::xowiki::Package initialize -ad_doc {
  import objects in xotcl format

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Aug 11, 2006
  @cvs-id $Id$
} -parameter {
  {create_user_ids 0}
  {replace 0}
}

set msg ""
ad_form \
    -name upload_form \
    -mode edit \
    -export {parent_id return_url} \
    -html { enctype multipart/form-data } \
    -form {
      {upload_file:file(file) {html {size 30}} {label "Import file for upload"} }
      {create_user_ids:integer(radio),optional {options {{yes 1} {no 0}}} {value 0} 
        {label "Create user_ids"}
        {help_text "If checked, import will create new user_ids if necessary"}
      }
      {replace:integer(radio),optional {options {{yes 1} {no 0}}} {value 0} 
        {label "Replace objects"}
        {help_text "If checked, import will delete the object if it exists and create it new, otherwise import just adds a revision"}
      }
      {ok_btn:text(submit) {label "[_ acs-templating.HTMLArea_SelectUploadBtn]"}
      }
    } \
    -on_submit {
      # check file name
      if {$upload_file eq ""} {
        template::form::set_error upload_form upload_file \
            [_ acs-templating.HTMLArea_SpecifyUploadFilename]
        break
      }

      set upload_tmpfile [template::util::file::get_property tmp_filename $upload_file]
      set f [open $upload_tmpfile]; 
      # if we do not set translation binary,
      # backslashes at the end of the lines might be lost
      fconfigure $f -translation binary -encoding utf-8
      set content [read $f]; close $f

      foreach o [::xowiki::Page allinstances] { 
        set preexists($o) 1
      }
      if {[catch {namespace eval ::xo::import $content} error]} {
	#my msg "Error: $::errorInfo"
        set msg "Error: $error\n$::errorInfo"
      } else {
        set objects [list]
        foreach o [::xowiki::Page allinstances] {
          if {![info exists preexists($o)]} {lappend objects $o}
        }
        ns_log notice "objects to import: $objects"
        set parent_id [ns_queryget parent_id 0]
        #::xotcl::Object msg parent_id=$parent_id
        if {[catch {
          set msg [$package_id import -replace $replace -create_user_ids $create_user_ids \
                       -parent_id $parent_id -objects $objects]
        } errMsg]} {
          ns_log notice "Error during import: $errMsg\nErrInfo: $::errorInfo"
          ::xotcl::Object msg "Error during import: $errMsg\nErrInfo: $::errorInfo"
          foreach o $objects {$o destroy}
          error $errMsg
        }
        foreach o $objects {if {[::xotcl::Object isobject $o]} {$o destroy}}
      }
      namespace delete ::xo::import
    }


set return_url [ns_queryget return_url ../]
set title "Import XoWiki Pages"
set context .
ad_return_template
