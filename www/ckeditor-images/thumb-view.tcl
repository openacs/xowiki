ad_page_contract {
	
} {
  {parent_id ""}
} -validate {
  parent_id_exists -requires {parent_id} {
    if {[xo::dc 0or1row object_exists "select item_id from cr_items where item_id =:parent_id"] == 0} {
      #ad_complain "Das angegebene Objekt existiert nicht."
    }
  }	 
}

set output ""
set return_url [ns_urlencode "[ad_conn url]?parent_id=$parent_id"]
db_multirow -extend url sub_files get_children "
select package_id,name,cr.item_id ,revision_id,mime_type, to_char(publish_date, 'yyyy-mm-dd, HH:MM') as date 
from cr_items ci inner join cr_revisions cr on (ci.item_id = cr.item_id)
join acs_objects o on o.object_id=cr.item_id
	where parent_id = :parent_id and revision_id = ci.live_revision 
	AND cr.mime_type LIKE 'image/%'
	ORDER BY publish_date DESC" {
		::xowiki::Package initialize -package_id $package_id
		set item [::xowiki::File get_instance_from_db -item_id $item_id]
		set url "[$item pretty_link]"
	}

set server_url ""
