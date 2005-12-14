ad_page_contract {
  display information about revisions of content items

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$
} {
  page_id:integer,notnull
  {title ""}
} -properties {
  title:onevalue
  context:onevalue
  page_id:onevalue
  revisions:multirow
  gc_comments:onevalue
}

set context [list [list [export_vars -base view {{item_id $page_id}}] $title ] \
                 [_ xotcl-core.revisions]]
set title "[_ xotcl-core.revision_title] '$title'"

# most things happen in the adp-include file from xotcl-core

# stuff for general comments
set return_url [ad_conn url]?[export_vars page_id]
if { [apm_package_installed_p "general-comments"] && 
     [ad_parameter "GeneralCommentsP" -package_id [ad_conn package_id]] } {
    set gc_link [general_comments_create_link $page_id $return_url]
    set gc_comments [general_comments_get_comments $page_id $return_url]
} else {
    set gc_link ""
    set gc_comments ""
}

