ad_page_contract {
	
} {
	parent_id:notnull,integer 
	revision:notnull,integer 
} 

set item_id [content::revision::item_id -revision_id $revision]
content::item::delete -item_id $item_id

ad_returnredirect thumb-view?parent_id=$parent_id
ad_script_abort

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
