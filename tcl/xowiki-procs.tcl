::xo::library doc {
    XoWiki - main library classes and objects

    @creation-date 2006-01-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {
  #
  # create classes for different kind of pages
  #
  ::xo::db::CrClass create Page -superclass ::xo::db::CrItem \
      -pretty_name "XoWiki Page" -pretty_plural "XoWiki Pages" \
      -table_name "xowiki_page" -id_column "page_id" \
      -mime_type text/html \
      -slots {
	::xo::db::CrAttribute create page_order \
	    -sqltype ltree -validator page_order -default ""
        ::xo::db::CrAttribute create creator
	# The following slots are defined elsewhere, but we override
	# some default values, such as pretty_names, required state, 
	# help text etc.
	::xo::Attribute create name \
	    -help_text #xowiki.Page-name-help_text# \
	    -validator name \
	    -required false ;#true 
	::xo::Attribute create title \
	    -required false ;#true
	::xo::Attribute create description \
	    -spec "textarea,cols=80,rows=2" 
	::xo::Attribute create text \
	    -spec "richtext" 
	::xo::Attribute create nls_language \
	    -spec {select,options=[xowiki::locales]} \
            -default [ad_conn locale]
	::xo::Attribute create publish_date \
	    -spec date
	::xo::Attribute create last_modified \
	    -spec date
	::xo::Attribute create creation_user \
	    -spec user_id
      } \
      -parameter {
        {render_adp 1}
        {do_substitutions 1}
        {absolute_links 0}
      } \
      -form ::xowiki::WikiForm

  if {$::xotcl::version < 1.5} {
    ::xowiki::Page log "Error: at least, XOTcl 1.5 is required.\
	You seem to use XOTcl $::xotcl::version !!!"
  }

  ::xo::db::CrClass create PlainPage -superclass Page \
      -pretty_name "XoWiki Plain Page" -pretty_plural "XoWiki Plain Pages" \
      -table_name "xowiki_plain_page" -id_column "ppage_id" \
      -mime_type text/plain \
      -form ::xowiki::PlainWikiForm

  ::xo::db::CrClass create File -superclass Page \
      -pretty_name "XoWiki File" -pretty_plural "XoWiki Files" \
      -table_name "xowiki_file" -id_column "file_id" \
      -storage_type file \
      -form ::xowiki::FileForm

  ::xo::db::CrClass create PodcastItem -superclass File \
      -pretty_name "Podcast Item" -pretty_plural "Podcast Items" \
      -table_name "xowiki_podcast_item" -id_column "podcast_item_id" \
      -slots {
	::xo::db::CrAttribute create pub_date \
	    -datatype date \
	    -sqltype timestamp \
	    -spec "date,format=YYYY_MM_DD_HH24_MI"
	::xo::db::CrAttribute create duration \
	    -help_text "#xowiki.PodcastItem-duration-help_text#"
	::xo::db::CrAttribute create subtitle
	::xo::db::CrAttribute create keywords \
	    -help_text "#xowiki.PodcastItem-keywords-help_text#"
      } \
      -storage_type file \
      -form ::xowiki::PodcastForm
  
  ::xo::db::CrClass create PageTemplate -superclass Page \
      -pretty_name "XoWiki Page Template" -pretty_plural "XoWiki Page Templates" \
      -table_name "xowiki_page_template" -id_column "page_template_id" \
      -slots {
        ::xo::db::CrAttribute create anon_instances \
	    -datatype boolean \
            -sqltype boolean -default "f" 
      } \
      -form ::xowiki::PageTemplateForm

  ::xo::db::CrClass create PageInstance -superclass Page \
      -pretty_name "XoWiki Page Instance" -pretty_plural "XoWiki Page Instances" \
      -table_name "xowiki_page_instance"  -id_column "page_instance_id" \
      -slots {
        ::xo::db::CrAttribute create page_template \
            -datatype integer \
	    -references cr_items(item_id)
        ::xo::db::CrAttribute create instance_attributes \
            -sqltype long_text \
	    -default ""
      } \
      -form ::xowiki::PageInstanceForm \
      -edit_form ::xowiki::PageInstanceEditForm

  ::xo::db::CrClass create Object -superclass PlainPage \
      -pretty_name "XoWiki Object" -pretty_plural "XoWiki Objects" \
      -table_name "xowiki_object"  -id_column "xowiki_object_id" \
      -mime_type text/plain \
      -form ::xowiki::ObjectForm

  ::xo::db::CrClass create Form -superclass PageTemplate \
      -pretty_name "XoWiki Form" -pretty_plural "XoWiki Forms" \
      -table_name "xowiki_form"  -id_column "xowiki_form_id" \
      -slots {
        ::xo::db::CrAttribute create form \
            -sqltype long_text \
	    -default ""
        ::xo::db::CrAttribute create form_constraints \
            -sqltype long_text \
	    -default "" \
            -validator form_constraints \
	    -spec "textarea,cols=100,rows=5"
      } \
      -form ::xowiki::FormForm

  ::xo::db::CrClass create FormPage -superclass PageInstance \
      -pretty_name "XoWiki FormPage" -pretty_plural "XoWiki FormPages" \
      -table_name "xowiki_form_page" -id_column "xowiki_form_page_id" \
      -slots {
        ::xo::db::CrAttribute create assignee \
            -datatype integer \
	    -references parties(party_id) \
            -spec "party_id" 
        ::xo::db::CrAttribute create state -default ""
      }

  # create various extra tables, indices and views
  #
  ::xo::db::require index -table xowiki_form_page -col assignee
  ::xo::db::require index -table xowiki_page_instance -col page_template

  ::xo::db::require table xowiki_references \
        "reference integer references cr_items(item_id) on delete cascade,
         link_type [::xo::db::sql map_datatype text],
         page      integer references cr_items(item_id) on delete cascade"
  ::xo::db::require index -table xowiki_references -col reference


  ::xo::db::require table xowiki_last_visited \
       "page_id integer references cr_items(item_id) on delete cascade,
        package_id integer,
        user_id integer,
        count   integer,
        time    timestamp"
  ::xo::db::require index -table xowiki_last_visited -col user_id,page_id -unique true
  ::xo::db::require index -table xowiki_last_visited -col user_id,package_id
  ::xo::db::require index -table xowiki_last_visited -col time

  

  # Oracle has a limit of 3118 characters for keys, therefore no text as type for "tag"
  ::xo::db::require table xowiki_tags \
       "item_id integer references cr_items(item_id) on delete cascade,
        package_id integer,
        user_id integer references users(user_id),
        tag     varchar(3000),
        time    timestamp"
  ::xo::db::require index -table xowiki_tags -col user_id,item_id
  ::xo::db::require index -table xowiki_tags -col tag,package_id
  ::xo::db::require index -table xowiki_tags -col user_id,package_id
  ::xo::db::require index -table xowiki_tags -col package_id

  ::xo::db::require index -table xowiki_page -col page_order \
      -using [expr {[::xo::db::has_ltree] ? "gist" : ""}]

  set sortkeys [expr {[db_driverkey ""] eq "oracle" ? "" : ", ci.tree_sortkey, ci.max_child_sortkey"}]
  ::xo::db::require view xowiki_page_live_revision \
      "select p.*, cr.*,ci.parent_id, ci.name, ci.locale, ci.live_revision, \
	  ci.latest_revision, ci.publish_status, ci.content_type, ci.storage_type, \
	  ci.storage_area_key $sortkeys \
          from xowiki_page p, cr_items ci, cr_revisions cr  \
          where p.page_id = ci.live_revision \
            and p.page_id = cr.revision_id  \
            and ci.publish_status <> 'production'"


  #############################
  #
  # A simple autoname handler
  #
  # The autoname handler has the purpose to generate new names based
  # on a stem and a parent_id. Typically this is used for the
  # autonaming of FormPages. The goal is to generate "nice" names,
  # i.e. with rather small numbers.
  #
  # Instead of using the table below, another option would be to use
  # multiple sequences. However, these sequences would have dynamic
  # names, it is not clear, whether there are certain limits on the
  # number of sequences (in PostgresSQL or Oracle), the database 
  # dependencies would be larger than in this simple approach.
  #
  ::xo::db::require table xowiki_autonames \
       "parent_id integer references acs_objects(object_id) ON DELETE CASCADE,
        name    varchar(3000),
        count   integer"
  ::xo::db::require index -table xowiki_autonames -col parent_id,name -unique true

  ::xotcl::Object create autoname
  autoname proc generate {-parent_id -name} {
    db_transaction {
      set already_recorded [db_0or1row [my qn autoname_query] "
       select count from xowiki_autonames
       where parent_id = $parent_id and name = :name"]
      
      if {$already_recorded} {
        incr count
        db_dml [my qn update_autoname_counter] \
            "update xowiki_autonames set count = count + 1 \
              where parent_id = $parent_id and name = :name"
      } else {
        set count 1
        db_dml [my qn insert_autoname_counter] \
            "insert into xowiki_autonames (parent_id, name, count) \
             values ($parent_id, :name, $count)"
      }
    }
    return $name$count
  }

  autoname proc new {-parent_id -name} {
    while {1} {
      set generated_name [my generate -parent_id $parent_id -name $name]
      if {[::xo::db::CrClass lookup -name $generated_name -parent_id $parent_id] eq 0} {
        return $generated_name
      }
    }
  }
  
  #############################
  #
  # Create the xowiki_cache
  #
  # We do here the same as in xotcl-core/tcl/05-db-procs.tcl
  # Read there for the reasons, why the cache is not created in
  # a -init file.....
  #
  if {[catch {ns_cache flush xowiki_cache NOTHING}]} {
    ns_log notice "xotcl-core: creating xowiki cache"
    ns_cache create xowiki_cache -size 200000
  }

  #############################
  #
  # Page definitions
  #

  Page set recursion_count 0
  Page array set RE {
    include {{{([^<]+?)}}([&<\s]|$)}
    anchor  {\\\[\\\[([^\]]+?)\\\]\\\]}
    div     {&gt;&gt;([^&<]*?)&lt;&lt;([ \n]*)?}
    clean   {[\\](\{\{|&gt;&gt;|\[\[)}
    clean2  { <br */?> *(<div)}
  }
  Page set markupmap(escape)   [list "\\\[\[" \03\01 "\\\{\{" \03\02  "\\&gt;&gt;" \03\03]
  Page set markupmap(unescape) [list \03\01 "\[\["    \03\02 "\{\{"   \03\03 "&gt;&gt;"  ]

  #
  # templating and CSS
  #

  Page proc quoted_html_content text {
    list [ad_text_to_html $text] text/html
  }

  #
  # Operations on the whole instance
  #

  #
  # Page marshall/demarshall
  #
  Page instproc marshall {} {
    my instvar name
    my unset_temporary_instance_variables
    set old_creation_user  [my creation_user]
    set old_modifying_user [my set modifying_user]
    my set creation_user   [my map_party $old_creation_user]
    my set modifying_user  [my map_party $old_modifying_user]
    if {[regexp {^..:[0-9]+$} $name] ||
        [regexp {^[0-9]+$} $name]} {
      #
      # for anonymous entries, names might clash in the target
      # instance. If we create on the target site for anonymous
      # entries always new instances, we end up with duplicates.
      # Therefore, we rename anonymous entries during export to
      #    ip_address:port/item_id
      #
      set old_name $name
      set server [ns_info server]
      set port [ns_config ns/server/${server}/module/nssock port]
      set name [ns_info address]:${port}-[my item_id]
      set content [my serialize]
      set name $old_name
    } else {
      set content [my serialize]
    }
    my set creation_user  $old_creation_user
    my set modifying_user $old_modifying_user
    return $content
  }

  File instproc marshall {} {
    set fn [my full_file_name]
    my set __file_content [::base64::encode [::xowiki::read_file $fn]]
    next
  }
  
  Page instproc category_export {tree_name} {
    #
    # Build a command to rebuild the category tree on imports
    # (__map_command). In addition this method builds and maintains a
    # category map, which maps internal IDs into symbolic values
    # (__category_map).
    #
    # Ignore locale in get_id for now, since it seems broken    
    set tree_ids [::xowiki::Category get_mapped_trees -object_id [my package_id] \
                      -names [list $tree_name] -output tree_id]
    # Make sure to have only one tree_id, in case multiple trees are
    # mapped with the same name.
    set tree_id [lindex $tree_ids 0]
    array set data [category_tree::get_data $tree_id]
    set categories [list]
    if {[my exists __category_map]} {array set cm [my set __category_map]}
    foreach category [::xowiki::Category get_category_infos -tree_id $tree_id] {
      foreach {category_id category_name deprecated_p level} $category break
      lappend categories $level $category_name
      set names($level) $category_name
      set node_name $tree_name
      for {set l 1} {$l <= $level} {incr l} {append node_name /$names($l)}
      set cm($category_id) $node_name
    }
    set cmd [list my category_import \
                 -name $tree_name -description $data(description) \
                 -locale [lang::system::site_wide_locale] \
                 -categories $categories]
    if {![my exists __map_command] || [string first $cmd [my set __map_command]] == -1} {
      my append __map_command \n $cmd
    }
    my set __category_map [array get cm]
    #my log "cmd=$cmd"
  }

  Page instproc build_instance_attribute_map {form_fields} {
    #
    # Build the data structure for mapping internal values (IDs) into
    # string representations and vice versa. In particular, it builds
    # and maintains the __instance_attribute_map, which is an
    # associative list (attribute/value pairs) for form-field attributes.
    #
    #foreach f $form_fields {lappend fns [list [$f name] [$f info class]]}
    #my msg "page [my name] build_instance_attribute_map $fns"
    if {[my exists  __instance_attribute_map]} {
      array set cm [my set __instance_attribute_map]
    }
    foreach f $form_fields {
      set multiple [expr {[$f exists multiple] ? [$f set multiple] : 0}]
      #my msg "$f [$f name] cat_tree [$f exists category_tree] is fc: [$f exists is_category_field]"
      if {[$f exists category_tree] && [$f exists is_category_field]} {
        #my msg "page [my name] field [$f name] is a category_id from [$f category_tree]"
        set cm([$f name]) [list category [$f category_tree] $multiple]
        my category_export [$f category_tree]
      } elseif {[$f exists is_party_id]} {
        #my msg "page [my name] field [$f name] is a party_id"
        set cm([$f name]) [list party_id $multiple]
      }
    }
    if {[array exists cm]} {
      my set __instance_attribute_map [array get cm]
    }
  }

  Page instproc category_import {-name -description -locale -categories} {
    # Execute the category import for every tree name only once per request
    set key ::__xowiki_category_import($name)
    if {[info exists $key]} return

    # ok, it is the first request
    #my msg "... catetegoy_import [self args]"

    # Do we have a tree with the specified named mapped?
    set tree_ids [::xowiki::Category get_mapped_trees -object_id [my package_id] -locale $locale \
                      -names [list $name] -output tree_id]
    set tree_id [lindex $tree_ids 0]; # handle multiple mapped trees with same name
    if {$tree_id eq ""} {
      # The tree is not mapped, we import the category tree
      my log "...importing category tree $name"
      set tree_id [category_tree::import -name $name -description $description \
                       -locale $locale -categories $categories]
      category_tree::map -tree_id $tree_id -object_id [my package_id]
    }

    #
    # build reverse category_map
    foreach category [::xowiki::Category get_category_infos -tree_id $tree_id] {
      foreach {category_id category_name deprecated_p level} $category break
      lappend categories $level $category_name
      set names($level) $category_name
      set node_name $name
      for {set l 1} {$l <= $level} {incr l} {append node_name /$names($l)}
      set ::__xowiki_reverse_category_map($node_name) $category_id
    }
    #my msg "... catetegoy_import reverse map [array names ::__xowiki_reverse_category_map]"
    # mark the tree with this name as already imported
    set $key 1
  }


  Form instproc marshall {} {
    #set form_fields [my create_form_fields_from_form_constraints \
    #                     [my get_form_constraints]]
    #my log "--ff=$form_fields"
    #my build_instance_attribute_map $form_fields
    next
  }
  
  FormPage instproc map_values {map_type values} {
    # Map a list of values (for multi-valued form fields) 
    # my log "map_values $map_type, $values"
    set mapped_values [list]
    foreach value $values {lappend mapped_values [my map_value $map_type $value]}
    return $mapped_values
  }

  FormPage instproc map_value {map_type value} {
    my log "map_value $map_type, $value"
    if {$map_type eq "category" && $value ne ""} {
      #
      # map a category item
      #
      array set cm [my set __category_map]
      return $cm($value)
    } elseif {$map_type eq "party_id" && $value ne ""} {
      #
      # map a party_id
      #
      return [my map_party $value]
    } else {
      return $value
    }
  }

  FormPage instproc marshall {} {
    #
    # Handle mapping from IDs to symbolic representations in
    # form-field values. We perform the mapping on xowiki::FormPages
    # and not on xowiki::Forms, since a single xowiki::FormPages might
    # use different xowiki::Forms in its life-cycle.
    #
    # Note, that only types of form-fields implied by the derived form
    # constraints are recognized. E.g. in workflows, it might be
    # necessary to move e.g. category definitions into the global form
    # constraints.
    #
    set form_fields [my create_form_fields_from_form_constraints \
                         [my get_form_constraints]]
    my build_instance_attribute_map $form_fields
    
    # In case we have a mapping from IDs to external values, use it
    # and rewrite instance attributes. Note, that the marshalled
    # objects have to be flushed from memory later since the
    # representation of instances_attributes is changed by this
    # method.
    #
    if {[my exists __instance_attribute_map]} {
      # my log "+++ we have an instance_attribute_map for [my name]"
      # my log "+++ starting with instance_attributes [my instance_attributes]"
      array set use [my set __instance_attribute_map]
      array set multiple_index [list category 2 party_id 1]
      set ia [list]
      foreach {name value} [my instance_attributes] {
        #my log "marshall check $name $value [info exists use($name)]"
        if {[info exists use($name)]} {
          set map_type [lindex $use($name) 0]
          set multiple [lindex $use($name) $multiple_index($map_type)]
          #my log "+++ marshall check $name $value m=?$multiple"

          if {$multiple} {
            lappend ia $name [my map_values $map_type $value]
          } else {
            lappend ia $name [my map_value $map_type $value]
          }
        } else {
          # nothing to map
          lappend ia $name $value
        }
      }
      my set instance_attributes $ia
      #my log "+++ setting instance_attributes $ia"
    }
    set old_assignee [my assignee]
    my set assignee  [my map_party $old_assignee]
    set r [next]
    my set assignee  $old_assignee
    return $r
  }

  Page instproc map_party {party_id} {
    #my log "+++ $party_id"
    # So far, we just handle users, but we should support parties in
    # the future as well.
    if {$party_id eq "" || $party_id == 0} {
      return $party_id
    }
    acs_user::get -user_id $party_id -array info
    set result [list]
    foreach a {username email first_names last_name screen_name url} {
      lappend result $a $info($a)
    }
    return $result
  }

  Page instproc reverse_map_party {-entry -default_party {-create_user_ids 0}} {
    # So far, we just handle users, but we should support parties in
    # the future as well.http://localhost:8003/nimawf/admin/export

    array set "" $entry
    if {$(email) ne ""} {
      set id [party::get_by_email -email $(email)]
      if {$id ne ""} { return $id }
    } 
    if {$(username) ne ""} {
      set id [acs_user::get_by_username -username $(username)]
      if {$id ne ""} { return $id }
    }
    if {$create_user_ids} {
      my log "+++ create a new user username=$(username), email=$(email)"
      array set status [auth::create_user -username $(username) -email $(email) \
			    -first_names $(first_names) -last_name $(last_name) \
			    -screen_name $(screen_name) -url $(url)]
      if {$status(creation_status) eq "ok"} {
	return $status(user_id)
      }
      my log "+++ create user username=${username}, email=$(email) failed, reason=$status(creation_status)"
    }
    return $default_party
  }

 
  Page instproc reverse_map_party_attribute {-attribute {-default_party 0} {-create_user_ids 0}} {
    if {![my exists $attribute]} {
      my set $attribute $default_party
    } elseif {[llength [my set $attribute]] < 2} {
      my set $attribute $default_party
    } else {
      my set $attribute [my reverse_map_party \
                             -entry [my set $attribute] \
                             -default_party $default_party \
                             -create_user_ids $create_user_ids]
    }
  }

  Page instproc demarshall {-parent_id -package_id -creation_user {-create_user_ids 0}} {
    # this method is the counterpart of marshall
    my set parent_id $parent_id
    my set package_id $package_id 
    my reverse_map_party_attribute -attribute creation_user  \
        -default_party $creation_user -create_user_ids $create_user_ids
    my reverse_map_party_attribute -attribute modifying_user \
        -default_party $creation_user -create_user_ids $create_user_ids
    # If we import from an old database without page_order, provide a
    # default value
    if {![my exists page_order]} {my set page_order ""}
    # Check, if nls_language and lang are aligned.
    if {[regexp {^(..):} [my name] _ lang]} {
      if {[string range [my nls_language] 0 1] ne $lang} {
        set old_nls_language [my nls_language]
        my nls_language [my get_nls_language_from_lang $lang]
        ns_log notice "nls_language for item [my name] set from $old_nls_language to [my nls_language]"
      }
    }
    # in the general case, no more actions required
  }

  File instproc demarshall {args} {
    next
    # we have to care about recoding the file content
    my instvar import_file __file_content
    set import_file [ns_tmpnam]
    ::xowiki::write_file $import_file [::base64::decode $__file_content]
    catch {my unset full_file_name}
    unset __file_content
  }

  # set default values. 
  # todo: with slots, it should be easier to set default values
  # for non-existing variables
  PageInstance instproc demarshall {args} {
    # some older versions do not have anon_instances and no slots
    if {![my exists anon_instances]} {
      my set anon_instances "f"
    }
    next
  }
  Form instproc demarshall {args} {
    # Some older versions do not have anon_instances and no slots
    if {![my exists anon_instances]} {
      my set anon_instances "t"
    }
    next
  }


  FormPage instproc reverse_map_values {map_type values category_ids_name} {
    # Apply reverse_map_value to a list of values (for multi-valued
    # form fields)
    my upvar $category_ids_name category_ids
    set mapped_values [list]
    foreach value $values {lappend mapped_values [my reverse_map_value $map_type $value category_ids]}
    return $mapped_values
  }

  FormPage instproc reverse_map_value {map_type value category_ids_name} {
    # Perform the inverse function of map_value. During export, internal
    # representations are exchanged by string representations, which are
    # mapped here again to internal representations
    my upvar $category_ids_name category_ids
    if {[info exists ::__xowiki_reverse_category_map($value)]} {
      #my msg "map value '$value' (category tree: $use($name)) of [my name] to an ID"
      lappend category_ids $::__xowiki_reverse_category_map($value)
      return $::__xowiki_reverse_category_map($value)
    } elseif {$map_type eq "party_id"} {
      return [my reverse_map_party \
                  -entry $value \
                  -default_party $creation_user \
                  -create_user_ids $create_user_ids]
    } elseif {$value eq ""} {
      return ""
    } else {
      my msg "cannot map value '$value' (map_type $map_type)\
		of [my name] to an ID; maybe there is some\
		same_named category tree with less entries..."
      my msg "reverse category map has values [lsort [array names ::__xowiki_reverse_category_map]]"
      return ""
    }
  }

  FormPage instproc demarshall {-parent_id -package_id -creation_user {-create_user_ids 0}} {
    # reverse map assingees
    my reverse_map_party_attribute -attribute assignee -create_user_ids $create_user_ids
    #
    # The function will compute the category_ids, which are were used
    # to categorize this objects in the source instance.
    set category_ids [list]

    #my msg "[my name] check cm=[info exists ::__xowiki_reverse_category_map] && iam=[my exists __instance_attribute_map]"

    if {[info exists ::__xowiki_reverse_category_map] 
        && [my exists __instance_attribute_map]
      } {
      #my msg "we have a instance_attribute_map"

      #
      # replace all symbolic category values by the mapped IDs
      #
      set ia [list]
      array set use [my set __instance_attribute_map]
      array set multiple_index [list category 2 party_id 1]
      foreach {name value} [my instance_attributes] {
        #my msg "use($name) --> [info exists use($name)]"
        if {[info exists use($name)]} {
	  #my msg "try to map value '$value' (category tree: $use($name))"
          set map_type [lindex $use($name) 0]
          set multiple [lindex $use($name) $multiple_index($map_type)]
          if {$multiple eq ""} {set multiple 1}
          if {$multiple} {
            lappend ia $name [my reverse_map_values $map_type $value category_ids]
          } else {
            lappend ia $name [my reverse_map_value $map_type $value category_ids]
          }
        } else {
          # nothing to map
          lappend ia $name $value
        }
      }
      my set instance_attributes $ia
      #my msg  "[my name] saving instance_attributes $ia"
    }
    set r [next]
    my set __category_ids [lsort -unique $category_ids]
    return $r
  }

  ############################################
  #
  # conditions for policy rules
  #
  ############################################
  Page instproc condition=match {query_context value} {
    #
    # Conditon for conditional checks in policy rules
    # The match condition is called with an attribute 
    # name and a pattern like in
    #
    #  edit {
    #     {{match {name {*weblog}}} package_id admin} 
    #     {package_id write}
    #  }
    #
    # This example specifies that for a page named
    # *weblog, the method "edit" is only allowed
    # for package admins.
    #
    #my msg "query_context='$query_context', value='$value'"
    if {[llength $value] != 2} {
      error "two arguments for match required, [llength $value] passed (arguments='$value')"
    }
    if {[catch {
      set success [string match [lindex $value 1] [my set [lindex $value 0]]]
    } errorMsg]} {
      my log "error during match: $errorMsg"
      set success 0
    }
    return $success
  }

  Page instproc condition=regexp {query_context value} {
    #
    # Conditon for conditional checks in policy rules
    # The match condition is called with an attribute 
    # name and a pattern like in
    #
    #  edit               {
    #    {{regexp {name {(weblog|index)$}}} package_id admin} 
    #    {package_id write}
    #  }
    #
    # This example specifies that for a page ending with
    # weblog or index, the method "edit" is only allowed
    # for package admins.
    #
    #my msg "query_context='$query_context', value='$value'"
    if {[llength $value] != 2} {
      error "two arguments for regexp required, [llength $value] passed (arguments='$value')"
    }
    if {[catch {
      set success [regexp [lindex $value 1] [my set [lindex $value 0]]]
    } errorMsg]} {
      my log "error during regexp: $errorMsg"
      set success 0
    }
    return $success
  }

  Page instproc copy_content_vars {-from_object:required} {
    array set excluded_var {
      folder_id 1 package_id 1 absolute_links 1 lang_links 1 modifying_user 1
      publish_status 1 item_id 1 revision_id 1 last_modified 1
    }
    foreach var [$from_object info vars] {
      # don't copy vars starting with "__"
      if {[string match "__*" $var]} continue
      if {![info exists excluded_var($var)]} {
        my set $var [$from_object set $var]
      }
    }
  }

  Page proc import {-user_id -package_id -folder_id {-replace 0} -objects} {
    my log "DEPRECATED"
    if {![info exists package_id]}  {set package_id  [::xo::cc package_id]}
    set cmd  [list $package_id import -replace $replace]
    
    if {[info exists user_id]}   {lappend cmd -user_id $user_id}
    if {[info exists objects]}   {lappend cmd -objects $objects}
    eval $cmd
  }

  #
  # tag management, get_tags works on instance or gobally
  #

  Page proc save_tags {
       -package_id:required 
       -item_id:required 
       -revision_id:required 
       -user_id:required 
       tags
     } {
    db_dml [my qn delete_tags] \
        "delete from xowiki_tags where item_id = $item_id and user_id = $user_id"

    foreach tag [split $tags " ,;"] {
      db_dml [my qn insert_tag] \
          "insert into xowiki_tags (item_id,package_id, user_id, tag, time) \
           values ($item_id, $package_id, $user_id, :tag, current_timestamp)"
    }
    search::queue -object_id $revision_id -event UPDATE
  }

  Page proc get_tags {-package_id:required -item_id -user_id} {
    if {[info exists item_id]} {
      if {[info exists user_id]} {
        # tags for item and user
        set tags [db_list [my qn get_tags] \
               "SELECT distinct tag from xowiki_tags \
		where user_id=$user_id and item_id=$item_id and package_id=$package_id"]
      } else {
        # all tags for this item 
        set tags [db_list [my qn get_tags] \
                "SELECT distinct tag from xowiki_tags \
		where item_id=$item_id and package_id=$package_id"]
      }
    } else {
      if {[info exists user_id]} {
        # all tags for this user
        set tags [db_list [my qn get_tags] \
                "SELECT distinct tag from xowiki_tags \
                 where user_id=$user_id and package_id=$package_id"]
      } else {
        # all tags for the package
        set tags [db_list [my qn get_tags] \
                "SELECT distinct tag from xowiki_tags \
                 where package_id=$package_id"]
      }
    }
    join $tags " "
  }


  #
  # Methods of ::xowiki::Page
  #

  Page instforward query_parameter {%my set package_id} %proc
  Page instforward exists_query_parameter {%my set package_id} %proc
  Page instforward form_parameter {%my set package_id} %proc
  Page instforward exists_form_parameter {%my set package_id} %proc

  Page instproc lang {} {
    return [string range [my nls_language] 0 1]
  }

  Page instproc get_nls_language_from_lang {lang} {
    # Return the first nls_language matching the provided lang
    # prefix. This method is not precise (when e.g. two nls_languages
    # are defined with the same lang), but the only thing relvant is
    # the lang anyhow.  If nothing matches return empty.
    foreach nls_language [lang::system::get_locales] {
      if {[string range $nls_language 0 1] eq $lang} {
        return $nls_language
      }
    }
    return ""
  }

  Page instproc build_name {{-nls_language ""}} {
    #
    # Build the name of the page, based on the provided nls_language
    # This method strips existing language-prefixes and uses the
    # provided nls_language or the instance variable for the new name.
    # It handles as well anonymous pages, which are never equipped
    # with language prefixes. ::xowiki::File has its own method.
    #
    set name [my name]
    set stripped_name $name
    regexp {^..:(.*)$} $name _ stripped_name

    # prepend the language prefix only, if the entry is not empty
    if {$stripped_name ne ""} {
      #if {[my istype ::xowiki::PageInstance]} {
        #
        # Do not add a language prefix to anonymous pages
        #
        #set anon_instances [my get_from_template anon_instances f]
        #if {$anon_instances} {
        #  return $stripped_name
        #}
      #}
      if {$nls_language ne ""} {my nls_language $nls_language}
      set name [my lang]:$stripped_name
    }
    return $name
  }

  Page instproc set_resolve_context {-package_id:required -parent_id:required} {
    my set logical_parent_id $parent_id
    my set logical_package_id $package_id
  }

  Page instproc logical_parent_id {} {
    if {[my exists logical_parent_id]} {
      return [my set logical_parent_id]
    } else {
      return [my parent_id]
    }
  }

  Page instproc logical_package_id {} {
    if {[my exists logical_package_id]} {
      return [my set logical_package_id]
    } else {
      return [my package_id]
    }
  }

#   Page instproc init {} {    
#     my log "--W "
#     ::xo::show_stack
#     next
#   }

#   Page instproc destroy  {} {
#     my log "--W "
#     ::xo::show_stack
#     next
#   }
  
  Page instproc save args {
    [my package_id] flush_page_fragment_cache
    next
  }

  Page instproc save_new args {
    [my package_id] flush_page_fragment_cache
    next
  }

  Page instproc initialize_loaded_object {} {
    my instvar title
    if {[info exists title] && $title eq ""} {set title [my set name]}
    next
  }

  Page instproc get_instance_attributes {} {
    if {[my exists instance_attributes]} {
      return [my set instance_attributes]
    }
    return ""
  }

  Page instproc regsub_eval {{-noquote:boolean false} re string cmd {prefix ""}} {
    if {$noquote} {
      set map { \[ \\[ \] \\] \$ \\$ \\ \\\\}
    } else {
      set map { \" \\\" \[ \\[ \] \\] \$ \\$ \\ \\\\}
    }
    if {0 && $prefix eq "1"} {
      my msg "re=$re, string=$string cmd=$cmd"
      set c [regsub -all $re [string map $map $string] "\[$cmd\]"]
      my msg c0=$c
      regsub -all {\\1([$]?)\\2} $c {\\\\\1} c1
      my msg c1=$c1
      set s [subst $c1]
      my msg s=$s
      return $s
    }
    uplevel [list subst [regsub -all $re [string map $map $string] "\[$cmd\]"]]
  }

  Page instproc error_during_render {msg} {
    return "<div class='errorMsg'>$msg</div>"
  }

  Page instproc error_in_includelet {arg msg} {
    my instvar name
    return [my error_during_render "[_ xowiki.error_in_includelet]<br >\n$msg"]
  }
  
  Page ad_instproc resolve_included_page_name {page_name} {
    Determine the page object for the specified page name.
    The specified page name might have the form 
    //some_other_instance/page_name, in which case the 
    page is resolved from some other package instance.
    If the page_name does not contain a language prefix,
    the language prefix of the including page is used.
  } {
    if {$page_name ne ""} {
      set page [[my package_id] resolve_page_name_and_init_context -lang [my lang] $page_name]
      if {$page eq ""} {
        error "Cannot find page '$page_name' to be included in page '[my name]'"
      }
    } else {
      set page [self]
    }
    return $page
  }

  Page instproc instantiate_includelet {arg} {
    # we want to use package_id as proc-local variable, since the 
    # cross package reference might alter it locally
    set package_id [my logical_package_id]

    # do we have a wellformed list?
    if {[catch {set page_name [lindex $arg 0]} errMsg]} {
      # there must be something syntactically wrong
      return [my error_in_includelet $arg [_ xowiki.error-includelet-dash_syntax_invalid]]
    }
    #my msg "includelet: [lindex $arg 0], caller parms ? '[lrange $arg 1 end]'"

    # the include is either a includelet class, or a wiki page
    if {[my isclass ::xowiki::includelet::$page_name]} {
      # direct call, without page, not tailorable
      set page [::xowiki::includelet::$page_name new \
		    -package_id $package_id \
		    -name $page_name \
                    -locale [::xo::cc locale] \
		    -actual_query [::xo::cc actual_query]]
    } else {
      #
      # Include a wiki page, tailorable.
      #
      set page [my resolve_included_page_name $page_name]
      
      if {$page ne "" && ![$page exists __decoration]} {
	# 
	# we use as default decoration for included pages
	# the "portlet" decoration
	#
        $page set __decoration [$package_id get_parameter default-portlet-decoration portlet]
      }
    }

    if {$page ne ""} {
      $page set __caller_parameters [lrange $arg 1 end] 
      $page destroy_on_cleanup
      my set __last_includelet $page
      $page set __including_page [self]
      if {[$page istype ::xowiki::Includelet]} {
        $page initialize
      }
    }
    return $page
  }

  Page instproc render_includelet {includelet} {
    #
    # The passed includelet is either an instance of ::xowiki::Page or
    # of ::xowiki::Includelet
    #
    foreach {att value} [$includelet set __caller_parameters] {
      switch -- $att {
        -decoration {$includelet set __decoration $value}
        -title {$includelet set title $value}
      }
    }
    if {[$includelet exists __decoration] && [$includelet set __decoration] ne "none"} {
      $includelet mixin add ::xowiki::includelet::decoration=[$includelet set __decoration]
    }

    set c [$includelet info class]
    if {[$c exists cacheable] && [$c cacheable]} {
      $includelet mixin add ::xowiki::includelet::page_fragment_cache
    }

    if {[$includelet istype ::xowiki::Includelet]} {
      # call this always
      $includelet include_head_entries
    }

    # "render" might be cached
    if {[catch {set html [$includelet render]} errorMsg]} {
      ns_log error "$errorMsg\n$::errorInfo"
      set page_name [$includelet name]
      set html [my error_during_render [_ xowiki.error-includelet-error_during_render]]
    }
    #my log "--include includelet returns $html"
    return $html
  }

  Page instproc include_portlet {arg} {
    my log "+++ method [self proc] of [self class] is deprecated"
    return [my include $arg]
  }

  Page ad_instproc include {-configure arg} {
    Include the html of the includelet. The method generates
    an includelet object (might be an other xowiki page) and
    renders it and returns either html or an error message.
  } {
    set page [my instantiate_includelet $arg]
    if {$page eq ""} {
      return [my error_during_render [_ xowiki.error-includelet-unknown]]
    }
    if {[$page istype ::xowiki::Page]} {
      set package_id [$page package_id]
      set allowed [[$package_id set policy] check_permissions \
                       -package_id $package_id \
                       -user_id [::xo::cc set untrusted_user_id] \
                       $page view]
      if {!$allowed} {
        return "<div class='errorMsg'>Unsufficient priviledges to view content of [$page name].</div>"
      }
    }
    if {[info exists configure]} {
      eval $page configure $configure
    }
    return [my render_includelet $page]
  }

  Page instproc check_adp_include_path { adp_fn } {
    #
    # For security reasons, don't allow arbitrary paths to different
    # packages.  All allowed includelets must be made available
    # under xowiki/www (preferable xowiki/www/portlets/*). If the
    # provided path contains a admin/* admin rights are required.
    #
    if {[string match "admin/*" $adp_fn]} {
      set allowed [::xo::cc permission \
		       -object_id [my package_id] -privilege admin \
		       -party_id [::xo::cc user_id]]
      if {!$allowed} {
	return [list allowed $allowed msg "Page can only be included by an admin!" fn ""]
      }
    }
    if {[string match "/*" $adp_fn] || [string match "../*" $adp_fn]} {
      # Never allow absolute paths.
      #
      # Alternatively, we could allow url-based includes, and then using
      # set node [site_node::get -url [ad_conn url]]
      # permission::require_permission -object_id $node(object_id) -privilege read
      # ... or admin/* based checks like in rp.
      #
      return [list allowed 0 msg "Invalid name for adp_include" fn ""]
    }
    return [list allowed 1 msg "" fn /packages/[[my package_id] package_key]/www/$adp_fn]
  }

  Page instproc include_content {arg ch2} {
    # make recursion depth a global variable to ease the deletion etc.
    if {[catch {incr ::xowiki_inclusion_depth}]} {
      set ::xowiki_inclusion_depth 1
    }
    if {$::xowiki_inclusion_depth > 10} {
      return [my error_in_includelet $arg [_ xowiki.error-includelet-nesting_to_deep]]
    }
    if {[regexp {^adp (.*)$} $arg _ adp]} {
      if {[catch {lindex $adp 0} errMsg]} {
        # there is something syntactically wrong
        incr ::xowiki_inclusion_depth -1
        return [my error_in_includelet $arg [_ xowiki.error-includelet-adp_syntax_invalid]]
      }
      set adp [string map {&nbsp; " "} $adp]
      #
      # Check the provided name of the adp file
      #
      array set "" [my check_adp_include_path [lindex $adp 0]]
      if {!$(allowed)} {
        return [my error_in_includelet $arg $(msg)]
      }
      set adp_fn $(fn)
      #
      # check the provided arguments
      #
      set adp_args [lindex $adp 1]
      if {[llength $adp_args] % 2 == 1} {
        incr ::xowiki_inclusion_depth -1
        set adp $adp_args
        return [my error_in_includelet $arg [_ xowiki.error-includelet-adp_syntax_invalid]]
      }

      lappend adp_args __including_page [self]
      set including_page_level [template::adp_level]
      if {[catch {set page [template::adp_include $adp_fn $adp_args]} errorMsg]} {
        ns_log error "$errorMsg\n$::errorInfo"
        # in case of error, reset the adp_level to the previous value
        set ::template::parse_level $including_page_level 
        incr ::xowiki_inclusion_depth -1
        return [my error_in_includelet $arg \
                         [_ xowiki.error-includelet-error_during_adp_evaluation]]
      }

      return $page$ch2
    } else {
      # we have a direct (adp-less include)
      set html [my include [my unescape $arg]]
      #my log "--include includelet returns $html"
      incr ::xowiki_inclusion_depth -1
      return $html$ch2
    }
  }

  Page instproc div {arg} {
    if {$arg eq "content"} {
      return "<div id='content' class='column'>"
    } elseif {[string match "left-col*" $arg] \
              || [string match "right-col*" $arg] \
              || $arg eq "sidebar"} {
      return "<div id='$arg' class='column'>"
    } elseif {$arg eq "box"} {
      return "<div class='box'>"
    } elseif {$arg eq ""} {
      return "</div>"
    } else {
      return ""
    }
  }

  Page instproc unescape string {
    # Some browsers change {{cmd -flag "..."}} into {{cmd -flag &quot;...&quot;}}
    # We have to change this back
    return [string map [list "&gt;" > "&lt;" < "&quot;" \" "&amp;" & "&semicolon;" {;} ] $string]
  }

  Page instproc get_anchor_and_query {link} {
    #
    # strip anchor and query from link name
    #
    set anchor ""
    set query ""
    # remove anchor
    regexp {^([^#]*)(\#|%23)(.*)$} $link _ link . anchor
    # remove query part
    regexp {^(.*)[?]([^?]+)$} $link _ link query
    return [list link $link anchor $anchor query $query]
  }

  Page instproc normalize_internal_link_name {name stripped_name lang} {
    #
    # strip anchor and query from link name
    #
    set anchor ""
    set query ""
    # remove anchor
    regexp {^([^#]*)(\#|%23)(.*)$} $stripped_name _ stripped_name . anchor
    # remove query part
    regexp {^(.*)[?]([^?]+)$} $stripped_name _ stripped_name query

    # if we have an empty stripped name, it is a link to the current
    # page, maybe in a different language
    if {$stripped_name eq ""} {
      regexp {:([^:]+)$} $name _ stripped_name
    }
    
    set normalized_name [[my package_id] normalize_name $stripped_name]
    #my msg "input: [self args] - lang=[my lang], [my nls_language]"
    if {$lang  eq ""}   {set lang [my lang]}
    if {$name  eq ""}   {set name $lang:$normalized_name}
    #my msg result=[list name $name lang $lang normalized_name $normalized_name anchor $anchor]
    return [list name $name lang $lang normalized_name $normalized_name anchor $anchor query $query]
  }

  Page instforward item_ref -verbose {%my package_id} %proc
  
  Page ad_instproc package_item_ref {
    -default_lang:required 
    -parent_id:required 
    link
  } {

    The provided link might contain cross-package item_refs.  When the
    referenced package could not be resolved, the returned package_id
    is 0. Otherwise, this method returns the results of item_ref.

  } {
    set package_id [my package_id]
    set referenced_package_id [$package_id resolve_package_path $link link]
    if {$referenced_package_id == 0} {
      return [list item_id 0 parent_id 0]
    }
    if {$referenced_package_id != $package_id} {
      set parent_id [$referenced_package_id folder_id]
    }
    return [$referenced_package_id item_ref -default_lang $default_lang -parent_id $parent_id $link]
  }

  Page instproc create_link {arg} {
    #my msg [self args]
    set label $arg
    set link $arg
    set options ""
    regexp {^([^|]+)[|](.*)$} $arg _ link label
    regexp {^([^|]+)[|](.*)$} $label _ label options
    set options [my unescape $options]

    # Get the package_id from the provided path, and - if found -
    # return the shortened link relative to it.
    set package_id [[my package_id] resolve_package_path $link link]
    if {$package_id == 0} {
      # we treat all such links like external links
      if {[regsub {^//} $link / link]} {
        #
        # For local links (starting with //), we provide
        # a direct treatment. Javascript and CSS files are
        # included, images are rendered directly.
        #
	switch -glob -- [::xowiki::guesstype $link] {
	  text/css {
	    ::xo::Page requireCSS $link
	    return ""
	  }
	  application/x-javascript {
	    ::xo::Page requireJS $link
	    return ""
	  }
	  image/* {
	    Link create [self]::link \
		-page [self] \
                -name "" \
		-type localimage [list -label $label] \
		-href $link
	    eval [self]::link configure $options
	    return [self]::link
	  }
	}
      }
      set l [ExternalLink new [list -label $label] -href $link]
      eval $l configure $options
      return $l
    }

    #
    # TODO missing: typed links
    #
    ## do we have a typed link? prefix has more than two chars...
    #  if {[regexp {^([^:/?][^:/?][^:/?]+):((..):)?(.+)$} $link _ \
	# link_type _ lang  stripped_name]} {
    # set name file:$stripped_name
    #  } 

    array set "" [my get_anchor_and_query $link]

    set parent_id [expr {$package_id == [my package_id] ? 
                         [my parent_id] : [$package_id folder_id]}]

    if {[regexp {^:(..):(.+)$} $(link) _ lang stripped_name]} {
      # language link (it starts with a ':')
      array set "" [$package_id item_ref -default_lang [my lang] -parent_id $parent_id \
                        ${lang}:$stripped_name]
      set (link_type) language
    } else {
      array set "" [$package_id item_ref -default_lang [my lang] -parent_id $parent_id \
                        $(link)]
    }
    #my msg [array get ""]

    if {$label eq $arg} {set label $(link)}
    set item_name [string trimleft $(prefix):$(stripped_name) :]
    
    Link create [self]::link \
        -page [self] -form $(form) \
        -type $(link_type) [list -name $item_name] -lang $(prefix) \
	[list -anchor $(anchor)] [list -query $(query)] \
        [list -stripped_name $(stripped_name)] [list -label $label] \
        -parent_id $(parent_id) -item_id $(item_id) -package_id $package_id
    
    if {[catch {eval [self]::link configure $options} errorMsg]} {
      ns_log error "$errorMsg\n$::errorInfo"
      return "<div class='errorMsg'>Error during processing of options [list $options] of link of type [[self]::link info class]:<blockquote>$errorMsg</blockquote></div>"
    } else {
      return [self]::link
    }
  }


  Page instproc anchor {arg} {
    if {[catch {set l [my create_link $arg]} errorMsg]} {
      return "<div class='errorMsg'>Error during processing of anchor ${arg}:<blockquote>$errorMsg</blockquote></div>"
    }
    set html [$l render]
    $l destroy
    return $html
  }


  Page instproc substitute_markup {content} {
    #
    # The provided content and the returned result are strings
    # containing HTML (unless we have other rich-text encodings).
    #
    set baseclass [expr {[[my info class] exists RE] ? [my info class] : [self class]}]
    $baseclass instvar RE markupmap
    #my log "-- baseclass for RE = $baseclass"
    if {[my set mime_type] eq "text/enhanced"} {
      set content [ad_enhanced_text_to_html $content]
    }
    if {![my do_substitutions]} {return $content}
    set output ""
    set l ""
    foreach l0 [split $content \n] {
      append l [string map $markupmap(escape) $l0]
      if {[string first \{\{ $l] > -1 && [string first \}\} $l] == -1} {append l " "; continue}
      set l [my regsub_eval $RE(anchor)  $l {my anchor  "\1"} "1"]
      set l [my regsub_eval $RE(div)     $l {my div     "\1"}]
      set l [my regsub_eval $RE(include) $l {my include_content "\1" "\2"}]
      #regsub -all $RE(clean) $l {\1} l
      regsub -all $RE(clean2) $l { \1} l
      set l [string map $markupmap(unescape) $l]
      append output $l \n
      set l ""
    }
    #my log "--substitute_markup returns $output"
    return $output
  }


  Page instproc adp_subst {content} {
    #
    # The provided content and the returned result are strings
    # containing HTML.
    #
    #my msg "--adp_subst in [my name] vars=[my info vars]"
    set __ignorelist [list RE __defaults name_method object_type_key db_slot]
    foreach __v [my info vars] {
      if {[info exists $__v]} continue
      my instvar $__v
    }
    foreach __v [[my info class] info vars] {
      if {[lsearch -exact $__ignorelist $__v]>-1} continue
      if {[info exists $__v]} continue
      [my info class] instvar $__v
    }
    set __ignorelist [list __v __vars __l __ignorelist __varlist \
                          __last_includelet __unresolved_references \
                          text item_id content lang_links]

    # set variable current_user to ease personalization
    set current_user [::xo::cc set untrusted_user_id]

    set __vars [info vars]
    regsub -all [template::adp_variable_regexp] $content {\1@\2;noquote@} content_noquote
    #my log "--adp before adp_eval '[template::adp_level]'"
    #
    # The adp buffer has limited size. For large pages, it might happen
    # that the buffer overflows. In Aolserver 4.5, we can increase the
    # buffer size. In 4.0.10, we are out of luck.
    #
    set __l [string length $content]
    if {[catch {set __bufsize [ns_adp_ctl bufsize]}]} {
      set __bufsize 0
    }
    if {$__bufsize > 0 && $__l > $__bufsize} {
      # we have aolserver 4.5, we can increase the bufsize
      ns_adp_ctl bufsize [expr {$__l + 1024}]
    }
    set template_code [template::adp_compile -string $content_noquote]
    set my_parse_level [template::adp_level]
    if {[catch {set template_value [template::adp_eval template_code]} __errMsg]} {
      #
      # Something went wrong during substitution; prepare a
      # user-friendly error message containing a listing of the
      # available variables.
      #
      # compute list of possible variables
      set __varlist [list]
      set __template_variables__ "<ul>\n"
      foreach __v [lsort $__vars] {
        if {[array exists $__v]} continue ;# don't report  arrays
        if {[lsearch -exact $__ignorelist $__v]>-1} continue
        lappend __varlist $__v
        append __template_variables__ "<li><b>$__v:</b> '[set $__v]'\n"
      }
      append __template_variables__ "</ul>\n"
      set ::template::parse_level $my_parse_level 
      #my log "--adp after adp_eval '[template::adp_level]' mpl=$my_parse_level"
      return "<div class='errorMsg'>Error in Page $name: $__errMsg</div>$content<p>Possible values are$__template_variables__"
    }
    return $template_value
  }

  Page instproc get_description {-nr_chars content} {
    my instvar revision_id
    set description [my set description]
    if {$description eq "" && $content ne ""} {
      set description [ad_html_text_convert -from text/html -to text/plain -- $content]
    }
    if {$description eq "" && $revision_id > 0} {
      set body [db_string [my qn get_description_from_syndication] \
                           "select body from syndication where object_id = $revision_id" \
                           -default ""]
      set description [ad_html_text_convert -from text/html -to text/plain -- $body]
    }
    if {[info exists nr_chars] && [string length $description] > $nr_chars} {
      set description [string range $description 0 $nr_chars]...
    }
    return $description
  }

  Page instproc render_content {} {
    #my msg "-- '[my set text]'"
    set html ""; set mime ""
    foreach {html mime} [my set text] break
    if {[my render_adp]} {
      set html [my adp_subst $html]
    }
    return [my substitute_markup $html]
  }

  Page instproc set_content {text} {
    my text [list [string map [list >> "\n&gt;&gt;" << "&lt;&lt;\n"] \
                       [string trim $text " \n"]] text/html]
  }

  Page instproc get_rich_text_spec {field_name default} {
    my instvar package_id
    set spec ""
    foreach {s widget_spec} [$package_id get_parameter widget_specs] {
      foreach {page_name var_name} [split $s ,] break
      # in case we have no name (edit new page) we use the first value or the default.
      set name [expr {[my exists name] ? [my set name] : $page_name}]
      #my msg "--w T.name = '$name' var=$page_name ([string match $page_name $name]), $var_name $field_name ([string match $var_name $field_name])"
      if {[string match $page_name $name] &&
          [string match $var_name $field_name]} {
        set spec $widget_spec
	#my msg "setting spec to $spec"
        break
      }
    }
    if {$spec eq ""} {return $default}
    return $field_name:$spec
  }

  Page instproc validate=name {name} {
    upvar nls_language nls_language
    my set data [self]  ;# for the time being; change clobbering when validate_name becomes a method
    set success [::xowiki::validate_name]
    if {$success} {
      # set the instance variable with a potentially prefixed name
      # the classical validators do just an upvar
      my set name $name
    }
    return $success
  }
  Page instproc validate=page_order {value} {
    if {[my exists page_order]} {
      set page_order [string trim $value " ."]
      my page_order $page_order
      return [expr {![regexp {[^0-9a-zA-Z_.]} $page_order]}]
    }
    return 1
  }

  Page instproc update_references {page_id references} {
    db_dml [my qn delete_references] \
        "delete from xowiki_references where page = $page_id"
    foreach ref $references {
      foreach {r link_type} $ref break
      db_dml [my qn insert_reference] \
          "insert into xowiki_references (reference, link_type, page) \
           values ($r,:link_type,$page_id)"
    }
   }

  Page proc container_already_rendered {field} {
    if {![info exists ::xowiki_page_item_id_rendered]} {
      return ""
    }
    #my log "--OMIT and not $field in ([join $::xowiki_page_item_id_rendered ,])"
    return "and not $field in ([join $::xowiki_page_item_id_rendered ,])"
  }

  Page instproc footer {} {
    return ""
  }

  Page instproc get_content {} {
    return [my render -with_footer false]
  }

  Page instproc render {{-update_references:boolean false} {-with_footer:boolean true}} {
    #
    # prepare language links
    #
    my array set lang_links {found "" undefined ""}
    #
    # prepare references management
    #
    my set references [list]
    if {[my exists __extra_references]} {
      #
      # xowiki content-flow uses extra references, e.g. to forms.
      # TODO: provide a better interface for providing these kind of
      # non-link references.
      #
      my set references [my set __extra_references]
      my unset __extra_references
    }
    #my msg "[my name] setting unresolved_references 0"
    my set unresolved_references 0
    my set __unresolved_references [list]
    #
    # get page content and care about reference management
    #
    set content [my render_content]
    #
    # record references and clear it
    #
    #my msg "we have the content, update=$update_references, unresolved=[my set unresolved_references]"
    if {$update_references || [my set unresolved_references] > 0} {
      my update_references [my item_id] [lsort -unique [my set references]]
    }
    my unset references
    #
    # handle footer
    #
    if {$with_footer && [::xo::cc get_parameter content-type text/html] eq "text/html"} {
      append content "<DIV class='content-chunk-footer'>"
      if {![my exists __no_footer] && ![::xo::cc get_parameter __no_footer 0]} {
        append content [my footer]
      }
      append content "</DIV>\n"
    }
    return $content
  }



  Page instproc record_last_visited {-user_id} {
    my instvar item_id package_id
    if {![info exists user_id]} {set user_id [::xo::cc set untrusted_user_id]}
    if {$user_id > 0} {
      # only record information for authenticated users
      db_dml [my qn update_last_visisted] \
          "update xowiki_last_visited set time = current_timestamp, count = count + 1 \
           where page_id = $item_id and user_id = $user_id"
      if {[db_resultrows] < 1} {
        db_dml [my qn insert_last_visisted] \
            "insert into xowiki_last_visited (page_id, package_id, user_id, count, time) \
             values ($item_id, $package_id, $user_id, 1, current_timestamp)"
      }
    }
  }

  #
  # Some utility functions, called on different kind of pages
  # 
  Page instproc get_html_from_content {content} {
    # Check, whether we got the content through a classic 2-element
    # OpenACS templating widget or directly.  If the list is not
    # well-formed, it must be contained directly.
    if {![catch {set l [llength $content]}] 
	&& $l == 2 
	&& [string match "text/*" [lindex $content 1]]} {
      return [lindex $content 0]
    }
    return $content
  }

  Page instproc form_field_index {nodes} {
    set marker ::__computed_form_field_names($nodes)
    if {[info exists $marker]} return

    foreach n $nodes {
      if {![$n istype ::xowiki::formfield::FormField]} continue
      set ::_form_field_names([$n name]) $n
      my form_field_index [$n info children]
    }
    set $marker 1
  }

  Page instproc lookup_form_field {
    -name:required
    form_fields
  } {
    my form_field_index $form_fields

    set key ::_form_field_names($name)
    if {[info exists $key]} {
      return [set $key]
    }
    #
    # We have here a non-existing form-field. Maybe the entry in the
    # form was dynamically created, so we create it here on the fly...  
    #
    # For forms with variable numbers of entries, we allow wild-cards
    # in the field-names of the form constraints.
    #
    foreach name_and_spec [my get_form_constraints] {
      regexp {^([^:]+):(.*)$} $name_and_spec _ spec_name short_spec
      if {[string match $spec_name $name]} {
	set f [my create_form_fields_from_form_constraints [list $name:$short_spec]]
	set $key $f
	return $f
      }
    }
    if {[lsearch -exact [list fontname fontsize formatblock]  $name] == -1} {
      set names [list]
      foreach f $form_fields {lappend names [$f name]}
      my msg "No form field with name '$name' found\
	(available fields: [lsort [array names ::_form_field_names]])"
    }
    set f [my create_form_fields_from_form_constraints [list $name:text]]
    set $key $f
    return $f
  }

  Page instproc lookup_cached_form_field {
    -name:required
  } {
    set key ::_form_field_names($name)
    #my msg "FOUND($name)=[info exists $key]"
    if {[info exists $key]} {
      return [set $key]
    }
    error "No form field with name $name found"
  }

  Page instproc show_fields {form_fields} {
    # this method is for debugging only
    set msg ""
    foreach f $form_fields { append msg "[$f name] [namespace tail [$f info class]], " }
    my msg $msg
    my log "form_fields: $msg"
  }



  Page instproc translate {-from -to text} {
    set langpair $from|$to
    set ie UTF8
    #set url [export_vars -base http://translate.google.com/translate_t {langpair text}]
    #set r [xo::HttpRequest new -url $url]
    set r [xo::HttpRequest new -url http://translate.google.com/translate_t \
	       -post_data [export_vars {langpair text ie}] \
	       -content_type application/x-www-form-urlencoded]
    #my msg status=[$r set status]
    if {[$r set status] eq "finished"} {
      set data [$r set data]
      dom parse -simple -html $data doc
      $doc documentElement root
      set n [$root selectNodes {//div[@id="result_box"]}]
      #my msg "$text $from=>$to [$n asText]"
      return [$n asText]
    } else {
      util_user_message -message "Could not translate text, \
	status=[$r set status] reason=[$r set cancel_message]"
    }
  }


  #
  # Methods of ::xowiki::PlainPage
  #

  PlainPage parameter {
    {render_adp 0}
  }
  PlainPage array set RE {
    include {{{(.+?)}}([ \n\r])}
    anchor  {\\\[\\\[([^\]]+?)\\\]\\\]}
    div     {>>([^<]*?)<<}
    clean   {[\\](\{\{|>>|\[\[)}
    clean2  {(--DUMMY NOT USED--)}
  }
  PlainPage set markupmap(escape)   [list "\\\[\["  \03\01  "\\\{\{"  \03\02   {\>>}  \03\03]
  PlainPage set markupmap(unescape) [list  \03\01 "\[\["     \03\02 "\{\{"      \03\03 {>>}]

  PlainPage instproc unescape string {
    return $string
  }

  PlainPage instproc render_content {} {
    set html [my set text]
    if {[my render_adp]} {
      set html [my adp_subst $html]
    }
    return [my substitute_markup $html]
  }
  PlainPage instproc set_content {text} {
    my text $text
  }

  PlainPage instproc substitute_markup {raw_content} {
    #
    # The provided text is a raw text, that is transformed into HTML
    # markup for links etc.
    #
    [self class] instvar RE markupmap
    if {![my do_substitutions]} {
      return $raw_content
    }
    set html ""
    foreach l [split $raw_content \n] {
      set l [string map $markupmap(escape) $l]
      set l [my regsub_eval $RE(anchor)  $l {my anchor  "\1"}]
      set l [my regsub_eval $RE(div)     $l {my div     "\1"}]
      set l [my regsub_eval $RE(include) $l {my include_content "\1" ""}]
      #regsub -all $RE(clean) $l {\1} l
      set l [string map $markupmap(unescape) $l]
      append html $l \n
    }
    return $html
  }

  #
  # Methods of ::xowiki::File
  #

  File parameter {
    {render_adp 0}
  }
  File instproc build_name {name {fn ""}} {
    my instvar mime_type package_id
    set type file
    if {$name ne ""} {
      set stripped_name $name
      regexp {^(.*):(.*)$} $name _ _t stripped_name
    } else {
      set stripped_name $fn
      # Internet explorer seems to transmit the full path of the
      # filename. Just use the last part in such cases as name.
      regexp {[/\\]([^/\\]+)$} $stripped_name _ stripped_name
    }
    return ${type}:[::$package_id normalize_name $stripped_name]
  }
  File instproc full_file_name {} {
    if {![my exists full_file_name]} {
      if {[my exists item_id]} {
        my instvar text mime_type package_id item_id revision_id
        set storage_area_key [db_string [my qn get_storage_key] \
                  "select storage_area_key from cr_items where item_id=$item_id"]
        my set full_file_name [cr_fs_path $storage_area_key]/$text
        #my log "--F setting FILE=[my set full_file_name]"
      }
    }
    return [my set full_file_name]
  }
    
  File instproc render_content {} {
    my instvar name mime_type description parent_id package_id item_id creation_user
    # don't require permissions here, such that rss can present the link
    #set page_link [$package_id make_link -privilege public [self] download ""]

    set revision_id [[$package_id context] query_parameter revision_id]
    set query [expr {$revision_id ne "" ? "revision_id=$revision_id" : ""}]
    set page_link [$package_id pretty_link -download true -parent_id [my parent_id] -query $query [my name]]

    #my log "--F page_link=$page_link ---- "
    set t [TableWidget new -volatile \
               -columns {
                 AnchorField name -label [_ xowiki.Page-name]
                 Field mime_type -label "Content Type"
                 Field last_modified -label "Last Modified"
                 Field mod_user -label "By User"
                 Field size -label "Size"
               }]

    regsub {[.][0-9]+([^0-9])} [my set last_modified] {\1} last_modified
    $package_id get_lang_and_name -name $name lang stripped_name
    set label $stripped_name

    $t add \
        -name $stripped_name \
        -mime_type $mime_type \
        -name.href $page_link \
        -last_modified $last_modified \
        -mod_user [::xo::get_user_name $creation_user] \
        -size [file size [my full_file_name]]

    if {[string match image/* $mime_type]} {
      set l [Link new -volatile \
                 -page [self] -query $query \
                 -type image -name $name -lang "" \
                 -stripped_name $stripped_name -label $label \
                 -parent_id $parent_id -item_id $item_id -package_id $package_id]
      set image "<div >[$l render]</div>"
    } else {
      set image ""
    }
    return "$image[$t asHTML]\n<p>$description</p>"
  }

  PodcastItem instproc render_content {} {
    set content [next]
    append content <ul>
    foreach {label var} {
      #xowiki.title# title 
      #xowiki.PodcastItem-subtitle# subtitle 
      #xowiki.Page-creator# creator 
      #xowiki.PodcastItem-pub_date# pub_date 
      #xowiki.PodcastItem-duration# duration 
      #xowiki.PodcastItem-keywords# keywords
    } {
      append content "<li><em>$label:</em> [my set $var]\n"
    }
    append content </ul>
    return $content
  }

  #
  # PageTemplate specifics
  #
  PageTemplate parameter {
    {render_adp 0}
  }
  PageTemplate instproc count_usages {{-publish_status ready}} {
    return [::xowiki::PageTemplate count_usages -item_id [my item_id] -publish_status $publish_status]
  }

  PageTemplate proc count_usages {-item_id:required {-publish_status ready}} {
    set publish_status_clause [::xowiki::Includelet publish_status_clause -base_table i $publish_status]
    set count [db_string [my qn count_usages] \
		   "select count(page_instance_id) from xowiki_page_instance, cr_items i \ 
			where page_template = $item_id \
                        $publish_status_clause \
                        and page_instance_id = coalesce(i.live_revision,i.latest_revision)"]
    return $count
  }

  Page instproc css_class_name {{-margin_form:boolean true}} {
    # Determine the CSS class name for an HTML-form.
    #
    # We need this acually only for PageTemplate and FormPage, but
    # aliases will require XOTcl 2.0.... so we define it for the time
    # being on ::xowiki::Page
    set name [expr {$margin_form ? "margin-form " : ""}]
    set CSSname [my name]
    regexp {^..:(.*)$} $CSSname _ CSSname
    return [append name "Form-$CSSname"]
  }

  #
  # PageInstance methods
  #

  PageInstance proc get_list_from_form_constraints {-name -form_constraints} {
    set spec [::xowiki::PageInstance get_short_spec_from_form_constraints \
                  -name $name \
                  -form_constraints $form_constraints]
    set result [list]
    foreach spec [split $spec ,] {
      if {[regexp {^([^=]+)=(.*)$} $spec _ attr value]} {
        lappend result $attr $value
      } else {
        my log "can't parse $spec in attribute and value; ignoring"
      }
    }
    return $result
  }

  PageInstance proc get_short_spec_from_form_constraints {-name -form_constraints} {
    # For the time being we cache the form_constraints per request as a global
    # variable, which is reclaimed at the end of the connection. 
    #
    # We have to take care, that the variable name does not contain namespace-prefixes
    regsub -all :: $form_constraints ":_:_" var_name_suffix
    
    set varname ::xowiki_$var_name_suffix
    if {![info exists $varname]} {
      foreach name_and_spec $form_constraints {
        regexp {^([^:]+):(.*)$} $name_and_spec _ spec_name short_spec
        set ${varname}($spec_name) $short_spec
      }
    }
    if {[info exists ${varname}($name)]} {
      return [set ${varname}($name)]
    }
    return ""
  }

  PageInstance instproc get_short_spec {name} {
    my instvar page_template
    #set form_constraints [my get_from_template form_constraints]
    set form_constraints [my get_form_constraints]
    #my msg "fc of [my name] = $form_constraints"
    if {$form_constraints ne ""} {
      set s [::xowiki::PageInstance get_short_spec_from_form_constraints \
                  -name $name -form_constraints $form_constraints]
      #my msg "get_short_spec $name c=$form_constraints => '$s'"
      return $s
    }
    return ""
  }

  PageInstance instproc get_field_label {name value} {
    set short_spec [my get_short_spec $name]
    if {$short_spec ne ""} {
      set f [::xowiki::formfield::FormField new -volatile -name $name -spec $short_spec]
      if {![$f exists show_raw_value]} {
        set value [$f field_value $value]
      }
    }
    return $value
  }

  PageInstance instproc widget_spec_from_folder_object {name given_template_name} {
    # get the widget field specifications from the payload of the folder object
    # for a field with a specified name in a specified page template
    foreach {s widget_spec} [[my set parent_id] get_payload widget_specs] {
      foreach {template_name var_name} [split $s ,] break
      #ns_log notice "--w T.title = '$given_template_name' var=$name"
      if {([string match $template_name $given_template_name] || $given_template_name eq "") &&
          [string match $var_name $name]} {
        return $widget_spec
        #ns_log notice "--w using $widget for $name"
      }
    }
    return ""
  }
  PageInstance instproc get_field_type {name default_spec} {
    my instvar page_template
    # get widget spec from folder (highest priority)
    set spec [my widget_spec_from_folder_object $name [$page_template set name]]
    if {$spec ne ""} {
      return $spec
    }
    # get widget spec from attribute definition 
    set f [my create_raw_form_field -name $name -slot [my find_slot $name]]
    if {$f ne ""} {
      return [$f asWidgetSpec]
    }
    # use default widget spec
    return $default_spec
  }

  PageInstance instproc get_form {} {
    # get the (HTML) form of the ::xowiki::PageTemplates/::xowiki::Form
    return [my get_html_from_content [my get_from_template form]]
  }

  PageInstance instproc get_template_object {} {
    set id [my page_template]
    if {![my isobject ::$id]} {
      ::xo::db::CrClass get_instance_from_db -item_id $id
    }
    return ::$id
  }

  PageInstance instproc get_form_constraints {{-trylocal false}} {
    # PageInstances have no form_constraints
    return ""
  }
 
  #FormPage instproc save args {
  #  my debug_msg [my set instance attributes]
  #  my log "IA=[my set instance_attributes]"
  #  next
  #}

  FormPage instproc get_form_constraints {{-trylocal false}} {
    # We define it as a method to ease overloading.
    #my msg "is_form=[my isform]"
    if {$trylocal && [my isform]} {
      return [my property form_constraints]
    } else {
      #my msg "get_form_constraints returns '[my get_from_template form_constraints]'"
      return [my get_from_template form_constraints]
    }
  }

  PageInstance ad_instproc get_from_template {var {default ""}} {
    Get a property from the parent object (template). The parent
    object might by either an ::xowiki::Form or an ::xowiki::FormPage

    @return either the property value or a default value
  } {
    #my msg "get $var from template"
    set form_obj [my get_template_object]
    # The resulting page should be either a Form (PageTemplate) or
    # a FormPage (PageInstance)
    #
    #my msg "parent of self [my name] is [$form_obj name] type [$form_obj info class]"
    #
    # If it is as well a PageInstance, we find the information in the
    # properties of this page. Note, that we cannot distinguish here between 
    # intrinsic (starting with _) and extension variables, since get_from
    # template does not know about the logic with "_" (just "property" does). 
    #
    if {[$form_obj istype ::xowiki::PageInstance]} {
      #my msg "returning property $var from parent formpage => '[$form_obj property $var]'"
      return [$form_obj property $var]
    }

    #
    # .... otherwise, it should be an instance variable ....
    #
    if {[$form_obj exists $var]} {
      #my msg "returning parent instvar [$form_obj set $var]"
      return [$form_obj set $var]
    }
    #
    # .... or, we try to resolve it against a local property.
    #
    # This case is currently needed in the workflow case, where
    # e.g. anon_instances is tried to be catched from the first form,
    # which might not contain it, if e.g. the first form is a plain
    # wiki page.
    #
    #my msg "resolve property $var=>[my exists_property $var]"
    if {[my istype ::xowiki::FormPage] && [my exists_property $var]} {
      #my msg "returning local property [my property $var]"
      return [my property $var]
    }
    #
    # if everything fails, return the default.
    #
    #my msg "returning the default, parent is of type [$form_obj info class]"
    return $default
  }

  PageInstance instproc render_content {} {
    set html [my get_html_from_content [my get_from_template text]]
    set html [my adp_subst $html]
    return "<div class='[[my page_template] css_class_name -margin_form false]'>[my substitute_markup $html]</div>"
  }
  PageInstance instproc template_vars {content} {
    set result [list]
    foreach {_ _ v} [regexp -inline -all [template::adp_variable_regexp] $content] {
      lappend result $v ""
    }
    return $result
  }
  PageInstance instproc adp_subst {content} {
    # initialize template variables (in case, new variables are added to template)
    array set __ia [my template_vars $content]
    # add extra variables as instance attributes
    array set __ia [my set instance_attributes]

    foreach var [array names __ia] {
      #my log "-- set $var [list $__ia($var)]"
      # TODO: just for the lookup, whether a field is a richt text field,
      # there should be a more efficient and easier way...
      if {[string match "richtext*" [my get_field_type $var text]]} {
        # ignore the text/html info from htmlarea
	set value [lindex $__ia($var) 0]
      } else {
	set value $__ia($var)
      }
      # the value might not be from the form attributes (e.g. title), don't clear it.
      if {$value eq "" && [my exists $var]} continue
      my set $var [my get_field_label $var $value]
    }
    next
  }

  PageInstance instproc count_usages {{-publish_status ready}} {
    return [::xowiki::PageTemplate count_usages -item_id [my item_id] -publish_status $publish_status]
  }

  #
  # Methods of ::xowiki::Object
  #
  Object instproc render_content {} {
    if {[[self]::payload info methods content] ne ""} {
      set html [[self]::payload content]
      #my msg render-adp=[my render_adp]
      if {[my render_adp]} {
        set html [my adp_subst $html]
        return [my substitute_markup $html]
      } else {
        #return "<pre>[string map {> &gt; < &lt;} [my set text]]</pre>"
        return $html
      }
    }
  }

  Object instproc initialize_loaded_object {} {
    my set_payload [my set text]
    next
  }
  Object instproc set_payload {cmd} {
    set payload [self]::payload
    if {[my isobject $payload]} {$payload destroy}
    ::xo::Context create $payload -requireNamespace \
        -actual_query [::xo::cc actual_query]
    $payload set package_id [my set package_id]
    if {[catch {$payload contains $cmd} error ]} {
      ns_log error "content $cmd lead to error: $error\nDetails: $::errorInfo\n"
      ::xo::clusterwide ns_cache flush xotcl_object_cache [my item_id]
    }
    #my log "call init mixins=[my info mixin]//[$payload info mixin]"
    $payload init
  }
  Object instproc get_payload {var {default ""}} {
    set payload [self]::payload
    if {![my isobject $payload]} {
      ::xo::Context create $payload -requireNamespace
    }
    expr {[$payload exists $var] ? [$payload set $var] : $default}
  }

  #
  # Methods of ::xowiki::Form
  #
  Form instproc footer {} {
    return [my include [list form-menu -form_item_id [my item_id]]]
  }

  Form proc dom_disable_input_fields {{-with_submit 0} root} {
    set fields [$root selectNodes "//button | //input | //optgroup | //option | //select | //textarea "]
    set disabled [list]
    foreach field $fields {
      set type ""
      if {[$field hasAttribute type]} {set type [$field getAttribute type]}
      if {$type eq "submit" && !$with_submit} continue
      # Disabled fields are not transmitted from the form;
      # some applications expect hidden fields to be transmitted
      # to identify the context, so don't disable it...
      if {$type eq "hidden"} continue
      $field setAttribute disabled "disabled"
      if {[$field hasAttribute name]} {
        lappend disabled [$field getAttribute name]
      }
    }

    #set fa [$root selectNodes {//input[@name='__form_action']}]
    #if {$fa ne ""} {
    #  $fa setAttribute value "view-form-data"
    #}
    return $disabled
  }

  Form proc disable_input_fields {{-with_submit 0} form} {
    dom parse -simple -html $form doc
    $doc documentElement root
    my dom_disable_input_fields -with_submit $with_submit $root
    set form [lindex [$root selectNodes //form] 0]
    Form add_dom_attribute_value $form class "margin-form"
    return [$root asHTML]
  }

  Form proc add_dom_attribute_value {dom_node attr value} {
    if {[$dom_node hasAttribute $attr]} {
      set old_value [$dom_node getAttribute $attr]
      if {[lsearch -exact $old_value $value] == -1} {
        append value " " $old_value
      } else {
        set value $old_value
      }
    }
    $dom_node setAttribute $attr $value
  }

  Form instproc render_content {} {
    my instvar text form
    ::xowiki::Form requireFormCSS

    # we assume, that the richtext is stored as 2-elem list with mime-type
    #my log "-- text='$text'"
    if {[lindex $text 0] ne ""} {
      my do_substitutions 0
      set html ""; set mime ""
      foreach {html mime} [my set text] break
      set content [my substitute_markup $html]
    } elseif {[lindex $form 0] ne ""} {
      set content [[self class] disable_input_fields [lindex $form 0]]
    } else {
      set content ""
    }
    return $content
  }

  Form instproc get_form_constraints args {
    # We define it as a method to ease overloading.
    return [my form_constraints]
  }

  Page instproc list {} {
    # todo move me
    my view [my include [list form-usages -form_item_id [my item_id]]]
  }

  Page instproc csv-dump {} {
    my instvar package_id
    if {[my info class] ne "::xowiki::FormPage" && [my info class] ne "::xowiki::Form"} {
      error "not called on a form"
    }
    set form_item_id [my item_id]
    set items [::xowiki::FormPage get_form_entries \
                   -base_item_ids $form_item_id -form_fields "" -initialize false \
                   -publish_status all -package_id $package_id]
    # collect all instances attributes of all items
    foreach i [$items children] {array set vars [$i set instance_attributes]}
    array set vars [list _name 1 _last_modified 1 _creation_user 1]
    set attributes [lsort -dictionary [array names vars]]
    # make sure, we the includelet honors the cvs generation
    set includelet_key name:form-usages,form_item_ids:$form_item_id,field_names:[join $attributes " "],
    ::xo::cc set queryparm(includelet_key) $includelet_key
    # call the includelet
    my view [my include [list form-usages -field_names $attributes \
			     -extra_form_constraints _creation_user:numeric,format=%d \
			     -form_item_id [my item_id] -generate csv]]
  }

  Page instproc create_form_fields_from_form_constraints {form_constraints} {
    #
    # Create form-fields from form constraints.
    # Since create_raw_form_field uses destroy_on_cleanup, we do not
    # have to care here about destroying the objects.
    #
    set form_fields [list]
    foreach name_and_spec $form_constraints {
      regexp {^([^:]+):(.*)$} $name_and_spec _ spec_name short_spec
      if {[string match "@table*" $spec_name] || $spec_name eq "@categories"} continue
      
      #my msg "checking spec '$short_spec' for form field '$spec_name'"
      lappend form_fields [my create_raw_form_field \
                   -name $spec_name \
                   -slot [my find_slot $spec_name] \
                   -spec $short_spec]
    }
    return $form_fields
  }

  Page instproc validate=form_constraints {form_constraints} {
    #
    # First check for invalid meta characters for security reasons.
    #
    if {[regexp {[\[\]]} $form_constraints]} {
      my uplevel [list set errorMsg \
                      [_ xowiki.error-form_constraint-invalid_characters]]
      return 0
    }
    #
    # Create from fields from all specs and report, if there are any errors
    #
    if {[catch {
      my create_form_fields_from_form_constraints $form_constraints
    } errorMsg]} {
      ns_log error "$errorMsg\n$::errorInfo"
      my uplevel [list set errorMsg $errorMsg]
      #my msg "ERROR: invalid spec '$short_spec' for form field '$spec_name' -- $errorMsg"
      return 0
    }
    return 1
  }

  #
  # Methods of ::xowiki::FormPage
  #
  FormPage instproc initialize_loaded_object {} {
    if {[my exists page_template]} {
      ::xo::db::CrClass get_instance_from_db -item_id [my page_template]
    }
    my array set __ia [my instance_attributes]
    next
  }
  FormPage instproc initialize {} {
    # can be overloaded
  }

  FormPage instproc condition=in_state {query_context value} {
    # possible values can be or-ed together (e.g. initial|final)
    foreach v [split $value |] {
      #my msg "check [my state] eq $v"
      if {[my state] eq $v} {return 1}
    }
    return 0
  }

  FormPage proc get_form_entries {
       -base_item_ids 
       -package_id 
       -form_fields 
       {-publish_status ready}
       {-parent_id ""}
       {-extra_where_clause ""}
       {-h_where {tcl true h "" vars "" sql ""}}
       {-always_queried_attributes ""}
       {-orderby ""}
       {-page_size 20}
       {-page_number ""}
       {-initialize true}
     } {
    #
    # Get query attributes for all tables (to allow e.g. sorting by time)
    #
    # The basic essential fields item_id, name, object_type and
    # publish_status are always automatically fetched from the
    # instance_select_query. Add the query attributes, we want to
    # obtain as well automatically.
    #
    # "-parent_id empty" means to get instances, regardless of 
    # parent_id. Under the assumption, page_template constrains
    # the query enough to make it fast...
    #
    set sql_atts [list ci.parent_id bt.revision_id bt.instance_attributes \
                      bt.creation_date bt.creation_user bt.last_modified \
                      "bt.object_package_id as package_id" bt.title \
                      bt.page_template
                     ]
    if {$always_queried_attributes eq "*"} {
      lappend sql_atts \
          bt.object_type bt.object_id \
          bt.description bt.publish_date bt.mime_type nls_language "bt.data as text" \
          bt.creator bt.page_order bt.page_id \
          bt.page_instance_id \
          bt.assignee bt.state bt.xowiki_form_page_id
    } else {
      foreach att $always_queried_attributes {
        set name [string range $att 1 end]
        lappend sql_atts bt.$name
      }
    }

    #
    # Compute the list of field_names from the already covered sql
    # attributes
    #
    set covered_attributes [list _name _publish_status _item_id _object_type]
    foreach att $sql_atts {
      regexp {[.]([^ ]+)} $att _ name
      lappend covered_attributes _$name
    }

    #
    # Collect SQL attributes from form_fields
    #
    foreach f $form_fields {
      if {![$f exists __base_field]} continue
      set field_name [$f name]
      if {[lsearch -exact $covered_attributes $field_name] > -1} {
        continue
      }
      if {$field_name eq "_text"} {
        lappend sql_atts "bt.data as text"
      } else {
        lappend sql_atts bt.[$f set __base_field]
      }
    }
    #my msg sql_atts=$sql_atts

    #
    # Build WHERE clause 
    # 
    set publish_status_clause [::xowiki::Includelet publish_status_clause -base_table ci $publish_status]
    set filter_clause ""
    array set wc $h_where
    set use_hstore [expr {[::xo::db::has_hstore] && 
                          [$package_id get_parameter use_hstore 0] 
                        }]
    if {$use_hstore} {
      set filter_clause " and '$wc(h)' <@ bt.hkey"
    }
    #my msg "exists sql=[info exists wc(sql)]"
    if {$wc(sql) ne ""} {
      foreach filter $wc(sql) {
        append filter_clause "and $filter"
      }
    }
    #my msg filter_clause=$filter_clause

    set sql  [::xowiki::FormPage instance_select_query \
		    -select_attributes $sql_atts \
		    -from_clause "" \
		    -where_clause " bt.page_template in ([join $base_item_ids ,]) \
			$publish_status_clause $filter_clause $extra_where_clause" \
		    -orderby $orderby \
		    -with_subtypes false \
		    -parent_id $parent_id \
		    -page_size $page_size \
		    -page_number $page_number \
		    -base_table xowiki_form_pagei \
                 ]
    #my log $sql
    #
    # When we query all attributes, we return objects named after the
    # item_id (like for single fetches)
    #
    set named_objects [expr {$always_queried_attributes eq "*"}]
    set items [::xowiki::FormPage instantiate_objects -sql $sql \
                   -named_objects $named_objects -object_named_after "item_id" \
                   -object_class ::xowiki::FormPage -initialize $initialize]

    if {!$use_hstore && $wc(tcl) ne "true"} {
      # Make sure, that the expr method is available; 
      # in xotcl 2.0 this will not be needed
      ::xotcl::alias ::xowiki::FormPage expr -objscope ::expr
      
      set init_vars $wc(vars)
      foreach p [$items children] {
        array set __ia $init_vars
        array set __ia [$p instance_attributes]
        if {![$p expr $wc(tcl)]} {$items delete $p}
      }
    }
    return $items
  }
  
   #
  # begin property management
  #

  FormPage instproc property_key {name} {
    if {[regexp {^_([^_].*)$} $name _ varname]} {
      return $varname
    } {
      return __ia($name)
    }
  }

  FormPage instproc exists_property {name} {
    return [my exists [my property_key $name]]
  }

  FormPage instproc property {name {default ""}} {
    set key  [my property_key $name]
    #my msg "$key [my exists $key] //[my array names __ia]//"
    if {[my exists $key]} {
      return [my set $key]
    }
    return $default
  }

  FormPage instproc set_property {{-new 0} name value} {
    if {[string match "_*" $name]} {
      set key [string range $name 1 end]
      set instance_attributes_refresh 0
    } {
      set key  __ia($name)
      set instance_attributes_refresh 1
    }
    if {!$new && ![my exists $key]} {
      error "property '$name' ($key) does not exist. \
        you might use flag '-new 1' for set_property to create new properties\n[lsort [my info vars]]"
    }
    my set $key $value
    if {$instance_attributes_refresh} {
      my instance_attributes [my array get __ia]
    }
    return $value
  }

  FormPage instproc get_property {-source -name:required {-default ""}} {
    if {![info exists source]} {
      set page [self]
    } else {
      set page [my resolve_included_page_name $source]
    }
    return [$page property $name $default]
  }

  FormPage instproc condition=is_true {query_context value} {
    # 
    # This condition maybe called from the policy rules. 
    # The passed value is a tuple of the form 
    #     {property-name operator property-value}
    #
    foreach {property_name op property_value} $value break
    if {![info exists property_value]} {return 0}

    #my log "$value => [my adp_subst $value]"
    array set wc [::xowiki::FormPage filter_expression [my adp_subst $value] &&]
    #my log "wc= [array get wc]"
    array set __ia $wc(vars)
    array set __ia [my instance_attributes]
    #my log "expr $wc(tcl) returns => [expr $wc(tcl)]"
    return [expr $wc(tcl)]
  }

  #
  # end property management
  #
  
  FormPage instproc set_publish_status {value} {
    if {[lsearch -exact [list production ready] $value] == -1} {
      error "invalid value '$value'; use 'production' or 'ready'"
    }
    my set publish_status $value
  }

  FormPage instproc isform {} {
    return [my exists_property form_constraints]
  }

  FormPage instproc footer {} {
    if {[my exists __no_form_page_footer]} {
      next
    } else {
      set is_form [my property is_form__ 0]
      if {[my isform]} {
        return [my include [list form-menu -form_item_id [my item_id] \
                                -buttons [list new answers [list form [my page_template]]]]]
      } else {
        return [my include [list form-menu -form_item_id [my page_template] -buttons form]]
      }
    }
  }


  FormPage instproc form_attributes {} {
    my log "DEPRECATRED, use 'field_names_from_form' instead "
    return [my field_names_from_form]
  }

  FormPage instproc field_names_from_form {{-form ""}} {
    #
    # this method returns the form attributes (including _*)
    #
    my instvar page_template
    set allvars [concat [[my info class] array names db_slot] \
                     [::xo::db::CrClass set common_query_atts]]

    set template [my get_html_from_content [my get_from_template text]]
    #my msg template=$template

    #set field_names [list _name _title _description _creator _nls_language _page_order]
    set field_names [list]
    if {$form eq ""} {set form [my get_form]}
    if {$form eq ""} {
      foreach {var _} [my template_vars $template] {
        #if {[string match _* $var]} continue
	if {[lsearch $allvars $var] == -1 
            && [lsearch $field_names $var] == -1} {lappend field_names $var}
      }
      set from_HTML_form 0
    } else {
      foreach {match 1 att} [regexp -all -inline [template::adp_variable_regexp] $form] {
        #if {[string match _* $att]} continue
        lappend field_names $att
      }
      dom parse -simple -html $form doc
      $doc documentElement root
      set fields [$root selectNodes "//*\[@name != ''\]"]
      foreach field $fields {
        set node_name [$field nodeName]
	if {$node_name ne "input" 
            && $node_name ne "textarea" 
            && $node_name ne "select" 
          } continue
	set att [$field getAttribute name]
        #if {[string match _* $att]} continue
	if {[lsearch $field_names $att] == -1} {
	  lappend field_names $att
	}
      }
      set from_HTML_form 1
    }
    return [list $from_HTML_form $field_names]
  }


  FormPage instproc render_content {} {
    my instvar doc root package_id page_template
    set text [lindex [my get_from_template text] 0]
    if {$text ne ""} {
      #my msg "we have a template text='$text'"
      # we have a template
      return [next]
    } else {
      #my msg "we have a form '[my get_form]'"
      set form [my get_form]
      if {$form eq ""} {return ""}

      ::xowiki::Form requireFormCSS

      foreach {form_vars field_names} [my field_names_from_form -form $form] break
      my array unset __field_in_form
      if {$form_vars} {foreach v $field_names {my set __field_in_form($v) 1}}
      set form_fields [my create_form_fields $field_names]
      my load_values_into_form_fields $form_fields
        
      # deactivate form-fields and do some final sanity checks
      foreach f $form_fields {$f set_disabled 1}
      my form_fields_sanity_check $form_fields

      set form [my regsub_eval  \
		    [template::adp_variable_regexp] $form \
		    {my form_field_as_html -mode display "\\\1" "\2" $form_fields}]
      
      # we parse the form just for the margin-form.... maybe regsub?
      dom parse -simple -html $form doc
      $doc documentElement root
      set form_node [lindex [$root selectNodes //form] 0]

      Form add_dom_attribute_value $form_node class [$page_template css_class_name]
      # The following two commands are for non-generated form contents
      my set_form_data $form_fields
      Form dom_disable_input_fields $root 
      # Return finally the result
      return [$root asHTML]
    }
  }


  FormPage instproc get_value {{-field_spec ""} {-cr_field_spec ""} before varname} {
    #
    # Read a property (instance attribute) and return
    # its pretty value in variable substitutions.
    #
    if {![my exists_property $varname]} {
      # We check for current_user here. In case the property does
      # not exist, we provide a value from the currently connected
      # user.
      if {$varname eq "current_user"} {
        set value [::xo::cc set untrusted_user_id]
      } else {
        set value ""
      }
    } else {
      set value [my property $varname]

      # todo: might be more efficient to check, if the field exists already
      set f [my create_form_field -cr_field_spec $cr_field_spec -field_spec $field_spec $varname]
      $f value $value

      if {[$f hide_value]} {
        set value ""
      } elseif {![$f exists show_raw_value]} {
        set value [$f pretty_value $value]
      }
    }
    return $before$value
  }

  FormPage instproc adp_subst {content} {
    # Get the default field specs once and pass it to every field creation
    set field_spec [my get_short_spec @fields]
    set cr_field_spec [my get_short_spec @cr_fields]

    # Iterate over the variables for substitution
    set content [my regsub_eval -noquote true \
                     [template::adp_variable_regexp] " $content" \
		     {my get_value -field_spec $field_spec -cr_field_spec $cr_field_spec "\\\1" "\2"}]

    return [string range $content 1 end]
  }

  Page instproc is_new_entry {old_name} {
    return [expr {[my publish_status] eq "production" && $old_name eq [my revision_id]}]
  }

  Page instproc unset_temporary_instance_variables {} {
    # never save/cache __ia or __field_in_form
    my array unset __ia
    my array unset __field_in_form
  }

  Page instproc map_categories {category_ids} {
    # could be optimized, if we do not want to have categories (form constraints?)
    #my log "--category::map_object -remove_old -object_id [my item_id] <$category_ids>"
    category::map_object -remove_old -object_id [my item_id] $category_ids
  }

  Page instproc save_data {{-use_given_publish_date:boolean false} old_name category_ids} {
    #my log "-- [self args]"
    my unset_temporary_instance_variables

    my instvar package_id name

    db_transaction {
      #
      # if the newly created item was in production mode, but ordinary entries
      # are not, change on the first save the status to ready
      #
      if {[my is_new_entry $old_name]} {
        if {![$package_id get_parameter production_mode 0]} {
          my set publish_status "ready"
        }
      }
      my map_categories $category_ids

      my save -use_given_publish_date $use_given_publish_date
      #my log "-- old_name $old_name, name $name"
      if {$old_name ne $name} {
        #my msg "do rename from $old_name to $name"
        $package_id flush_name_cache -name $old_name -parent_id [my parent_id]
        my rename -old_name $old_name -new_name $name
      }
    }
    return [my item_id]
  }

}

::xo::library source_dependent 

