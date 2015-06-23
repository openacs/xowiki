ad_page_contract {
	
} {
	parent_id:notnull,naturalnum 
	revision:notnull,integer 
} 

set item_id [content::revision::item_id -revision_id $revision]

 content::item::delete -item_id $item_id


ad_returnredirect thumb-view?parent_id=$parent_id