ad_page_contract {
    Permissions for the subsite itself.
    
    @author Gustaf Neumann
    @creation-date 2006-08-10
    @cvs-id $Id$
} {
    package_id:integer
}

set page_title "[apm_instance_name_from_id $package_id] Permissions"

set context [list $page_title]
set return_url [apm_package_url_from_id $package_id]admin

