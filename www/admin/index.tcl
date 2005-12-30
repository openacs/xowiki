ad_page_contract {
  This is the admin page for the package.  It displays all of the types for 
  Notes and provides links to delete them

    @author Your Name (you@example.com)
    @cvs-id $Id$
} -query {
  object_type:optional
}

set context [list]
set supertype ::xowiki::Page
set object_type_key [$supertype set object_type_key]

set page_title "Administer all kind of [$supertype set pretty_plural]"

template::list::create \
    -name admin_index \
    -elements {	
      delete {
	link_url_col delete_url 
	display_template {
	  Delete object type with all subtypes and instances
	  <img title='Delete object type with all subtypes and instances' \
	      src='/resources/acs-subsite/Delete16.gif' \
	      alt='delete' width="16" height="16" border="0">
	}
	sub_class narrow
      }
      nr_instances {
	link_url_col instances_url
	label Instances
      }
      object_type {
	label "Object Type"
      }
    }

db_multirow \
    -extend {
      delete_url
      instances_url
      nr_instances
    } admin_index type_index_select "
        select object_type from acs_object_types where 
        tree_sortkey between :object_type_key and tree_right(:object_type_key)
    " {

      set delete_url [export_vars -base delete-type {object_type}]
      if {[$object_type info class] eq "::xotcl::Class"} {
	# for backward comatibility with 5.1, since we define PageTemplate as plain xotcl class;
	# only necessary to avoid crash, when entries are already in the database
	continue
	#set nr_instances 0
      } else {
	set nr_instances [db_list count [$object_type instance_select_query \
					     -count 1 \
					     -with_subtypes false]]
      }
      set instances_url [export_vars -base ../index {object_type}]
    }

set template admin_index