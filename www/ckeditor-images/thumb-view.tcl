ad_page_contract {
	
} {
    {parent_id:naturalnum ""}
} -validate {
    parent_id_exists -requires {parent_id} {
	if {[xo::dc 0or1row object_exists "select item_id from cr_items where item_id = :parent_id"] == 0} {
	    ad_complain "Specified item does not exist"
	}
    }
}

set output ""
set return_url [export_vars -base [ad_conn url] -no_empty {parent_id}]
db_multirow -extend {
  delete_url
  download_url
  img_id
  image_p
} sub_files get_children "
select package_id,name,cr.title,cr.item_id,revision_id,mime_type, to_char(publish_date, 'yyyy-mm-dd, HH:MM') as date 
 from cr_items ci inner join cr_revisions cr on (ci.item_id = cr.item_id)
join acs_objects o on o.object_id=cr.item_id
	where parent_id = :parent_id and revision_id = ci.live_revision 
        AND cr.mime_type LIKE 'image/%'
	ORDER BY publish_date DESC" {
          ::xowiki::Package initialize -package_id $package_id
          set item [::xowiki::File get_instance_from_db -item_id $item_id]
	  set url [$item pretty_link]
          set download_url [export_vars -base $url {{m download}}]
          set delete_url [export_vars -base $url {{m delete} return_url}]
          set img_id "preview-img-${revision_id}"
          set image_p [expr {$mime_type in {"image/jpeg" "image/png" "image/gif"}}]
	}


set server_url ""

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
