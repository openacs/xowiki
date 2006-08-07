# different template testing DONE
# orphan creation DONE
# orphan deletions completion  DONE
# link resolver DONE
# edit-new parameter name DONE
# cgi package_id missing DONE
# delete all DONE
# $parent_id set package_id DONE
# lang link DONE
# unknown link DONE
# weblog DONE
# tag edit DONE
# tag new DONE
# weblog on the fly creation DONE
# behavior without index page DONE
# renaming objects DONE
# handling of sc DONE
# make subst_blank_in_name default DONE
# package parameters and payload of folder object DONE
# permissions management DONE
# permissions admin DONE
# include DONE
# edit page template DONE
# edit page instance DONE
# delete folder object DONE
# the flag store_folder_id should not be necessary
# move require folder object code
# edit-new last_page_id (needed?)
# edit last_page_id (needed?)


namespace eval ::xowiki {
  
  Page instproc view {} {
    # view is used only for the toplevel call, when the xowiki page is viewed
    # this is not inteded for embedded wiki pages
    my instvar package_id item_id 
    $package_id instvar folder_id  ;# this is the root folder
    ::xowiki::Page set recursion_count 0

    set content [my render]
    my log "--after render"

    if {[$package_id get_parameter "use_user_tracking" 1]} {
      my record_last_visited
    }

    my log "--after user_tracking"
    set references [my references]
    my log "--after references = <$references>"

    # export title, text, and lang_links to current scope
    my instvar title name text lang_links

    set tags ""
    set no_tags 1
    if {[$package_id get_parameter "use_tags" 1] && 
	![my exists_query_parameter no_tags]} {
      # only activate tags when the user is logged in
      set no_tags [expr {[ad_conn user_id] == 0}]
      set tags ""
      if {!$no_tags} {
	::xowiki::Page requireJS  "/resources/xowiki/get-http-object.js"
	set entries [list]
	set tags [lsort [::xowiki::Page get_tags -user_id [ad_conn user_id] \
			     -item_id $item_id -package_id $package_id]]
	set href [site_node::get_url_from_object_id -object_id $package_id]weblog?summary=1
	foreach tag $tags {lappend entries "<a href='$href&tag=[ad_urlencode $tag]'>$tag</a>"}
	set tags_with_links [join $entries {, }]
      }
    }

    my log "--after tags"
    set return_url  [$package_id url]     ;# for the time being

    if {[$package_id get_parameter "use_gc"] && 
	![my exists_query_parameter no_gc]} {
      set gc_link     [general_comments_create_link -object_name $title $item_id $return_url]
      set gc_comments [general_comments_get_comments $item_id $return_url]
    } else {
      set gc_link ""
      set gc_comments ""
    }

    set header_stuff [::xowiki::Page header_stuff]
    set master [my query_parameter "master" 1]
    if {[my exists_query_parameter "edit_return_url"]} {
      set return_url [my query_parameter "edit_return_url"]
    }

    my log "--after gc title=$title"
    if {$master} {
      set context [list $title]
      set object_type [my info class]
      set rev_link    [my make_link [self] revisions]
      set edit_link   [my make_link [self] edit return_url]
      set delete_link [my make_link [self] delete] 
      set new_link    [my make_link $package_id edit-new object_type] 
      set admin_link  [my make_link -privilege admin -url admin/ $package_id {} {}] 
      set index_link  [my make_link -privilege public -url "" $package_id {} {}]
      set save_tag_link [my make_link [self] save-tags]
      set popular_tags_link [my make_link [self] popular-tags]

      my log "--after context delete_link=$delete_link "
      set template [$folder_id get_payload template]
      set page [self]

      if {$template ne ""} {
	set __including_page $page
	set __adp_stub [acs_root_dir]/packages/xowiki/www/view-default
	set template_code [template::adp_compile -string $template]
	if {[catch {set content [template::adp_eval template_code]} errmsg]} {
	  set content "Error in Page $name: $errmsg<br>$content"
	} else {
	  ns_return 200 text/html $content
	}
      } else {
	# use adp file
	set template_file [my query_parameter "template_file" \
			       [$folder_id get_payload template_file view-default]]
	if {![regexp {^[./]} $template_file]} {
	  set template_file /packages/xowiki/www/$template_file
	}
	$package_id return_page -adp $template_file -variables {
	  references name title item_id page context header_stuff return_url
	  content references lang_links package_id
	  rev_link edit_link delete_link new_link admin_link index_link 
	  tags no_tags tags_with_links save_tag_link popular_tags_link 
	  gc_link gc_comments 
	}
      }
    } else {
      ns_return 200 text/html $content
    }
  }

  Page instproc edit {{-new:boolean false}} {
    my instvar package_id item_id revision_id
    $package_id instvar folder_id  ;# this is the root folder

    #-query {
    #  item_id:integer,optional
    #  name:optional
    #  last_page_id:integer,optional
    #  folder_id:integer,optional
    #  {object_type:optional ::xowiki::Page}
    #  page_template:integer,optional
    #  return_url:optional
    #}

    # set some default values if they are provided
    foreach key {name title last_page_id} {
      if {[$package_id exists_query_parameter $key]} {my set $key [$package_id query_parameter $key]}
    }

    set object_type [my info class]
    if {!$new && $object_type eq "::xowiki::Object" && [my set name] eq "::$folder_id"} {
      # if we edit the folder object, we have to do some extra magic here, 
      # since  the folder object has slightly different naming conventions.
      # ns_log notice "--editing folder object ::$folder_id, FLUSH $page"
      ns_cache flush xotcl_object_cache [self]
      ns_cache flush xotcl_object_cache ::$folder_id
      my move ::$folder_id
      set page ::$folder_id
      #ns_log notice "--move page=$page"
    } 

    #
    # setting up folder id for file selector (use community folder if available)
    #
    set fs_folder_id ""
    if {[info commands dotlrn_fs::get_community_shared_folder] ne ""} {
      set fs_folder_id [dotlrn_fs::get_community_shared_folder \
			    -community_id [dotlrn_community::get_community_id]]
    }

    # the following line is like [$package_id url], but works as well with renames of the object
    set myurl [expr {$new ? [$package_id url] :
		     [Page pretty_link -package_id $package_id [my form_parameter name]]}]
    if {[my exists_query_parameter "return_url"]} {
      set submit_link [my query_parameter "return_url" $myurl]
      set return_url $submit_link
    } else {
      set submit_link $myurl
    }
    my log "--u sumit_link=$submit_link qp=[my query_parameter return_url]"

    # we have to do template mangling here; ad_form_template writes form variables into the 
    # actual parselevel, so we have to be in our own level in order to access an pass these
    variable ::template::parse_level
    lappend parse_level [info level]    
    set action_vars [expr {$new ? "{edit-new 1} object_type return_url" : "{m edit} return_url"}]
    [$object_type getFormClass -data [self]] create ::xowiki::f1 -volatile \
	-action  [export_vars -base [$package_id url] $action_vars] \
	-data [self] \
	-folderspec [expr {$fs_folder_id ne "" ?"folder_id $fs_folder_id":""}] \
	-submit_link $submit_link

    if {[info exists return_url]} {
      ::xowiki::f1 generate -export [list [list return_url $return_url]]
    } else {
      ::xowiki::f1 generate
    }
    ::xowiki::f1 instvar edit_form_page_title context formTemplate
    
    if {[info exists item_id]} {
      set rev_link    [my make_link [self] revisions]
      set view_link   [my make_link [self] view]
    }
    if {[info exists last_page_id]} {
      set back_link [$package_id url]
    }

    set index_link  [my make_link -privilege public -url "" $package_id {} {}]
    set html [$package_id return_page -adp /packages/xowiki/www/edit \
		  -form f1 \
		  -variables {item_id edit_form_page_title context formTemplate
		    view_link back_link rev_link index_link}]
    template::util::lpop parse_level
    my log "--e html length [string length $html]"
    return $html
  }

  File instproc download {} {
    my instvar text mime_type package_id item_id revision_id
    $package_id set mime_type $mime_type
    $package_id set delivery \
	  [expr {[catch {ns_conn contentsentlength}] ? 
		 "ns_returnfile" : "ad_returnfile_background"}]
    #my log "--F FILE=[my full_file_name]"
    return [my full_file_name]
  }

  Page instproc revisions {} {
    my instvar package_id name item_id
    set context [list [list [$package_id url] $name ] [_ xotcl-core.revisions]]
    set title "[_ xotcl-core.revision_title] '$name'"
    set content [next]
    $package_id return_page -adp /packages/xowiki/www/revisions -variables {
      content context {page_id $item_id} title
    }
  }


  Page instproc make-live-revision {} {
    my instvar revision_id item_id package_id
    my log "--M set_live_revision($revision_id)"
    db_exec_plsql make_live {select content_item__set_live_revision(:revision_id)}
    set page_id [my query_parameter "page_id"]
    ns_cache flush xotcl_object_cache ::$item_id
    ad_returnredirect [my query_parameter "return_url" \
			   [export_vars -base [$package_id url] {{m revisions}}]]
  }


  Page instproc delete-revision {} {
    my instvar revision_id package_id item_id
    my log "--M delete revision($revision_id)"
    db_exec_plsql delete_revision {select content_revision__del(:revision_id)}
    ns_cache flush xotcl_object_cache ::$item_id
    ns_cache flush xotcl_object_cache ::$revision_id
    ad_returnredirect [my query_parameter "return_url" \
			   [export_vars -base [$package_id url] {{m revisions}}]]
  }

  Page instproc delete {} {
    my instvar package_id item_id name parent_id
    my log "--D trying to delete $item_id"
    ::Generic::CrItem delete -item_id $item_id
    ns_cache flush xotcl_object_cache ::$item_id
    # we should probably flush as well cached revisions
    if {$name eq "::$parent_id"} {
      my log "--D deleting folder object ::$parent_id"
      ns_cache flush xotcl_object_cache ::$parent_id
      ns_cache flush xotcl_object_type_cache item_id-of-$parent_id
      ::$parent_id destroy
    }
    set key link-*-$name-$parent_id
    foreach n [ns_cache names xowiki_cache $key] {ns_cache flush xowiki_cache $n}
    ad_returnredirect [my query_parameter "return_url" [$package_id package_url]]
  }

  Page instproc save-tags {} {
    my instvar package_id item_id
    ::xowiki::Page save_tags -user_id [ad_conn user_id] -item_id $item_id \
	-package_id $package_id [my form_parameter tags]
    ad_returnredirect [my query_parameter "return_url" [$package_id url]]
  }

  Page instproc popular-tags {} {
    my instvar package_id item_id parent_id
    set limit [my query_parameter "limit" 20]
    set href [$package_id package_url]weblog?summary=1
    set entries [list]
    db_foreach get_popular_tags \
	"select count(*) as nr,tag from xowiki_tags \
         where item_id=$item_id group by tag order by nr limit $limit" {
	   lappend entries "<a href='$href&ptag=[ad_urlencode $tag]'>$tag ($nr)</a>"
	 }
    ns_return 200 text/html "[_ xowiki.popular_tags_label]: [join $entries {, }]"
  }

  Class Page::skin=portlet -instproc render {} {
    return "<div class='portlet-title'>\
	<span><a href='[::xowiki::Page pretty_link [my name]]'>[my title]</a></span></div>\
	<div class='portlet'>[next]</div>"
  }
}