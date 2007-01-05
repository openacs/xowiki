::xowiki::Package initialize -ad_doc {
  import objects in xotcl format

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Aug 11, 2006
  @cvs-id $Id$

} 

set msg ""
ad_form \
    -name upload_form \
    -mode edit \
    -export {fs_package_id folder_id orderby selector_type file_types} \
    -html { enctype multipart/form-data } \
    -form {
      {upload_file:file(file) {html {size 30}} }
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
      set f [open $upload_tmpfile]; set content [read $f]; close $f

      foreach o [::xowiki::Page allinstances] { $o destroy }
      if {[catch {namespace eval ::xo::import $content} error]} {
        set msg "Error: $error"
      } else {
        set msg [::xowiki::Page import -replace 0]
      }
      namespace delete ::xo::import
    }


set title "Import XoWiki Pages"
set context {}
ad_return_template
