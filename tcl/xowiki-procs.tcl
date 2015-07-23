::xo::library doc {
  XoWiki - main library classes and objects

  @creation-date 2006-01-10
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki {
  #
  # Create classes for different kind of pages
  #
  ::xo::db::CrClass create Page -superclass ::xo::db::CrItem \
      -pretty_name "#xowiki.Page_pretty_name#" -pretty_plural "#xowiki.Page_pretty_plural#" \
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
            -spec "maxlength=400,required" \
            -required false ;#true
        #::xo::Attribute create title \
        #    -required false ;#true
        #::xo::Attribute create description \
        #    -spec "textarea,cols=80,rows=2"
        #::xo::Attribute create text \
        #    -spec "richtext"
        ::xo::Attribute create nls_language \
            -spec {select,options=[xowiki::locales]} \
            -default {[ad_conn locale]}
        #::xo::Attribute create publish_date \
        #    -spec date
        ::xo::Attribute create last_modified \
            -spec date
        ::xo::Attribute create creation_user \
            -spec user_id
      } \
      -extend_slot {title -required false} \
      -extend_slot {description -spec "textarea,cols=80,rows=2,label=#xowiki.Page-description#"} \
      -extend_slot {text -spec "richtext"} \
      -extend_slot {publish_date -spec "date,label=#xowiki.Page-publish_date#"} \
      -parameter {
        {render_adp 1}
        {do_substitutions 1}
        {absolute_links 0}
      } \
      -form ::xowiki::WikiForm

  if {$::xotcl::version < 1.5} {
    ::xowiki::Page log "Error: XOTcl 1.5 or newer is required.\
    You seem to use XOTcl $::xotcl::version !!!"
  }

  ::xo::db::CrClass create PlainPage -superclass Page \
      -pretty_name "#xowiki.PlainPage_pretty_name#" -pretty_plural "#xowiki.PlainPage_pretty_plural#" \
      -table_name "xowiki_plain_page" -id_column "ppage_id" \
      -mime_type text/plain \
      -form ::xowiki::PlainWikiForm

  ::xo::db::CrClass create File -superclass Page \
      -pretty_name "#xowiki.File_pretty_name#" -pretty_plural "#xowiki.File_pretty_plural#" \
      -table_name "xowiki_file" -id_column "file_id" \
      -storage_type file \
      -form ::xowiki::FileForm

  ::xo::db::CrClass create PodcastItem -superclass File \
      -pretty_name "#xowiki.PodcastItem_pretty_name#" -pretty_plural "#xowiki.PodcastItem_pretty_plural#" \
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
      -pretty_name "#xowiki.PageTemplate_pretty_name#" -pretty_plural "#xowiki.PageTemplate_pretty_plural#" \
      -table_name "xowiki_page_template" -id_column "page_template_id" \
      -slots {
        ::xo::db::CrAttribute create anon_instances \
            -datatype boolean \
            -sqltype boolean -default "f"
      } \
      -form ::xowiki::PageTemplateForm

  ::xo::db::CrClass create PageInstance -superclass Page \
      -pretty_name "#xowiki.PageInstance_pretty_name#" -pretty_plural "#xowiki.PageInstance_pretty_plural#" \
      -table_name "xowiki_page_instance"  -id_column "page_instance_id" \
      -slots {
        ::xo::db::CrAttribute create page_template \
            -datatype integer \
            -references "cr_items(item_id) ON DELETE CASCADE"
        ::xo::db::CrAttribute create instance_attributes \
            -sqltype long_text \
            -default ""
      } \
      -form ::xowiki::PageInstanceForm \
      -edit_form ::xowiki::PageInstanceEditForm

  ::xo::db::CrClass create Object -superclass PlainPage \
      -pretty_name "#xowiki.Object_pretty_name#" -pretty_plural "#xowiki.Object_pretty_plural#" \
      -table_name "xowiki_object"  -id_column "xowiki_object_id" \
      -mime_type text/plain \
      -form ::xowiki::ObjectForm

  ::xo::db::CrClass create Form -superclass PageTemplate \
      -pretty_name "#xowiki.Form_pretty_name#" -pretty_plural "#xowiki.Form_pretty_plural#" \
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
      -pretty_name "#xowiki.FormPage_pretty_name#" -pretty_plural "#xowiki.FormPage_pretty_plural#" \
      -table_name "xowiki_form_page" -id_column "xowiki_form_page_id" \
      -slots {
        ::xo::db::CrAttribute create assignee \
            -datatype integer \
            -references parties(party_id) \
            -spec "hidden"
        ::xo::db::CrAttribute create state -default ""
      }

  #
  # Create various extra tables, indices and views
  #
  ::xo::db::require index -table xowiki_form_page -col assignee
  ::xo::db::require index -table xowiki_page_instance -col page_template

  ::xo::db::require table xowiki_references [subst {
    reference   {integer references cr_items(item_id) on delete cascade}
    link_type   {[::xo::dc map_datatype text]}
    page        {integer references cr_items(item_id) on delete cascade}
  }]
  ::xo::db::require index -table xowiki_references -col reference
  ::xo::db::require index -table xowiki_references -col page


  ::xo::db::require table xowiki_last_visited {
    page_id    {integer references cr_items(item_id) on delete cascade}
    package_id integer
    user_id    integer
    count      integer
    time       timestamp
  }

  ::xo::db::require index -table xowiki_last_visited -col user_id,page_id -unique true
  ::xo::db::require index -table xowiki_last_visited -col user_id,package_id
  ::xo::db::require index -table xowiki_last_visited -col time
  ::xo::db::require index -table xowiki_last_visited -col page_id


  # Oracle has a limit of 3118 characters for keys, therefore we
  # cannot use "text" as type for "tag"
  ::xo::db::require table xowiki_tags {
    item_id    {integer references cr_items(item_id) on delete cascade}
    package_id integer
    user_id    {integer references users(user_id)}
    tag        varchar(3000)
    time       timestamp
  }
  ::xo::db::require index -table xowiki_tags -col user_id,item_id
  ::xo::db::require index -table xowiki_tags -col tag,package_id
  ::xo::db::require index -table xowiki_tags -col user_id,package_id
  ::xo::db::require index -table xowiki_tags -col package_id
  ::xo::db::require index -table xowiki_tags -col user_id
  ::xo::db::require index -table xowiki_tags -col item_id

  ::xo::db::require index -table xowiki_page -col page_order \
      -using [expr {[::xo::dc has_ltree] ? "gist" : ""}]

  #
  # view: xowiki_page_live_revision
  #

  set sortkeys [expr {[db_driverkey ""] eq "oracle" ? "" : ", ci.tree_sortkey, ci.max_child_sortkey"}]
  ::xo::db::require view xowiki_page_live_revision \
      "select p.*, cr.*,ci.parent_id, ci.name, ci.locale, ci.live_revision, \
      ci.latest_revision, ci.publish_status, ci.content_type, ci.storage_type, \
      ci.storage_area_key $sortkeys \
          from xowiki_page p, cr_items ci, cr_revisions cr  \
          where p.page_id = ci.live_revision \
            and p.page_id = cr.revision_id  \
            and ci.publish_status <> 'production'"

  #
  # xowiki_form_instance_item_index:
  #
  #   A materialized table of xowiki formpage instances, containing
  #   just the item information, but combined with other attributes
  #   frequently used for indexing (like page_id, paren_id, ... hkey).
  #
  #   Rationale: The quality of indices on cr_revisions tend to
  #   decrease when there are many revisions stored in the database,
  #   since the number of duplicates increases due to non-live
  #   revisions. This table can be used for indexing just the live
  #   revision on the item level. Example query combining package_id
  #   and page_template:
  #
  #      select count(*) from xowiki_form_instance_item_index
  #      where package_id = 18255683
  #         and page_template = 20260757
  #         and publish_status='ready';
  #
  #   In order to get rid of this helper table (may be to regenerate it
  #   on the next load) use
  #
  #       drop table xowiki_form_instance_item_index cascade;
  #
  #
  #ns_logctl severity Debug(sql) on

  #
  # $populate is a dml statement to populate the materialized index
  # xowiki_form_instance_item_index, when it does not exist.
  #
  set popuplate {
    insert into xowiki_form_instance_item_index (
           item_id, name, package_id, parent_id, publish_status,
           page_template, assignee, state )
    select ci.item_id, ci.name, o.package_id, ci.parent_id, ci.publish_status,
           xpi.page_template, xfp.assignee, xfp.state
    from cr_items ci
    join xowiki_page_instance xpi on (ci.live_revision = xpi.page_instance_id)
    join xowiki_form_page xfp on (ci.live_revision = xfp.xowiki_form_page_id)
    join acs_objects o on (o.object_id = ci.item_id)
  }

  if {[::xo::dc has_hstore]} {
    ::xo::db::require table xowiki_form_instance_item_index {
      item_id             {integer references cr_items(item_id) on delete cascade}
      name                {character varying(400)}
      package_id          {integer}
      parent_id           {integer references cr_items(item_id) on delete cascade}
      publish_status      {text}
      page_template       {integer references cr_items(item_id) on delete cascade}
      hkey                {hstore}
      assignee            {integer references parties(party_id) on delete cascade}
      state               {text}
    } $popuplate
    ::xo::db::require index -table xowiki_form_instance_item_index -col hkey -using gist
    set hkey_in_view "xi.hkey,"
  } else {
    ::xo::db::require table xowiki_form_instance_item_index {
      item_id             {integer references cr_items(item_id) on delete cascade}
      name                {character varying(400)}
      package_id          {integer}
      parent_id           {integer references cr_items(item_id) on delete cascade}
      publish_status      {text}
      page_template       {integer references cr_items(item_id) on delete cascade}
      assignee            {integer references parties(party_id) on delete cascade}
      state               {text}
    } $popuplate
    set hkey_in_view ""
  }

  ::xo::db::require index -table xowiki_form_instance_item_index -col item_id -unique true
  ::xo::db::require index -table xowiki_form_instance_item_index -col parent_id,name -unique true
  ::xo::db::require index -table xowiki_form_instance_item_index -col page_template
  ::xo::db::require index -table xowiki_form_instance_item_index -col page_template,package_id
  ::xo::db::require index -table xowiki_form_instance_item_index -col parent_id
  ::xo::db::require index -table xowiki_form_instance_item_index -col parent_id,page_template

  #
  # Define helper views in connection with the form_instance_item_index:
  #
  # - xowiki_form_instance_item_view
  # - xowiki_form_instance_children
  # - xowiki_form_instance_attributes

  #
  # - xowiki_form_instance_item_view:
  #
  #   A view similar to xowiki_form_pagei, but containing already
  #   often extra-joined attributes like parent_id. This view returns
  #   only the values of the live revisions, and uses the
  #   form_instance_item_index for quick lookup. Example query to
  #   obtain all attributes necessary for object creation based on
  #   package_id and page_template.
  #
  #      select * from xowiki_form_instance_item_view
  #      where package_id = 18255683
  #         and page_template = 20260757
  #         and publish_status='ready';
  #
  ::xo::db::require view xowiki_form_instance_item_view [subst {
      SELECT
         xi.package_id, xi.parent_id, xi.name,
         $hkey_in_view xi.publish_status, xi.assignee, xi.state, xi.page_template, xi.item_id,
         o.object_id, o.object_type, o.title AS object_title, o.context_id,
         o.security_inherit_p, o.creation_user, o.creation_date, o.creation_ip,
         o.last_modified, o.modifying_user, o.modifying_ip,
         --o.tree_sortkey, o.max_child_sortkey,
         cr.revision_id, cr.title, content_revision__get_content(cr.revision_id) AS text,
         cr.description, cr.publish_date, cr.mime_type, cr.nls_language,
         xowiki_form_page.xowiki_form_page_id,
         xowiki_page_instance.page_instance_id,
         xowiki_page_instance.instance_attributes,
         xowiki_page.page_id,
         xowiki_page.page_order,
         xowiki_page.creator
      FROM cr_text,
         xowiki_form_instance_item_index xi
         left join cr_items ci on (ci.item_id = xi.item_id)
         left join cr_revisions cr on (cr.revision_id = ci.live_revision)
         left join acs_objects o on (o.object_id = ci.live_revision)
         left join xowiki_page on (o.object_id = xowiki_page.page_id)
         left join xowiki_page_instance on (o.object_id = xowiki_page_instance.page_instance_id)
         left join xowiki_form_page on (o.object_id = xowiki_form_page.xowiki_form_page_id)
  }]

  # xowiki_form_instance_children:
  #
  #   Return the root_item_id and all attributes of the
  #   form_instance_item_index of all child items under the tree based
  #   on parent_ids. Use a query like the following to count the
  #   children of an item having a certain page_template (e.g.
  #   find all the folders/links/... having the the specified item
  #   as parent):
  #
  #      select count(*) from xowiki_form_instance_children
  #      where root_item_id = 18255779
  #         and page_template = 20260757
  #         and publish_status='ready';
  #
  #   Note: this query needs an oracle counter-part

  ::xo::db::require view xowiki_form_instance_children {
      With RECURSIVE child_items AS (
        select item_id as root_item_id, * from xowiki_form_instance_item_index
      UNION ALL
        select child_items.root_item_id, xi.* from xowiki_form_instance_item_index xi, child_items
        where xi.parent_id = child_items.item_id
      )
      select * from child_items
  }

  # xowiki_form_instance_attributes
  #
  #   Return for a given item_id the full set of attributes like the
  #   one returned from xowiki_form_instance_item_view. The idea is to
  #   make it convenient to obtain from a query all attributes
  #   necessary for creating instances. The same view can be used to
  #   complete either values from the xowiki_form_instance_item_index
  #
  #      select * from xowiki_form_instance_item_index xi
  #      left join xowiki_form_instance_attributes xa on xi.item_id = xa.item_id;
  #
  #   or from xowiki_form_instance_children
  #
  #      select * from xowiki_form_instance_children ch
  #      left join xowiki_form_instance_attributes xa on ch.item_id = xa.item_id;
  #
  #
  ::xo::db::require view xowiki_form_instance_attributes {
      SELECT
    ci.item_id,
         o.package_id,
         o.object_id, o.object_type, o.title AS object_title, o.context_id,
         o.security_inherit_p, o.creation_user, o.creation_date, o.creation_ip,
         o.last_modified, o.modifying_user, o.modifying_ip,
         --o.tree_sortkey, o.max_child_sortkey,
         cr.revision_id, cr.title, content_revision__get_content(cr.revision_id) AS data,
         cr_text.text_data AS text, cr.description, cr.publish_date, cr.mime_type, cr.nls_language,
         xowiki_form_page.xowiki_form_page_id,
         xowiki_page_instance.page_instance_id,
         xowiki_page_instance.instance_attributes,
         xowiki_page.page_id,
         xowiki_page.page_order,
         xowiki_page.creator
      FROM cr_text, cr_items ci
         left join cr_revisions cr on (cr.revision_id = ci.live_revision)
         left join acs_objects o on (o.object_id = ci.live_revision)
         left join xowiki_page on (o.object_id = xowiki_page.page_id)
         left join xowiki_page_instance on (o.object_id = xowiki_page_instance.page_instance_id)
         left join xowiki_form_page on (o.object_id = xowiki_form_page.xowiki_form_page_id)
  }

  #ns_logctl severity Debug(sql) off


  #############################
  #
  # A simple autoname handler
  #
  # The autoname handler has the purpose to generate new names based
  # on a stem and a parent_id. Typically this is used for the
  # auto-naming of FormPages. The goal is to generate "nice" names,
  # i.e. with rather small numbers.
  #
  # Instead of using the table below, another option would be to use
  # multiple sequences. However, these sequences would have dynamic
  # names, it is not clear, whether there are certain limits on the
  # number of sequences (in PostgresSQL or Oracle), the database
  # dependencies would be larger than in this simple approach.
  #
  ::xo::db::require table xowiki_autonames {
    parent_id "integer references acs_objects(object_id) ON DELETE CASCADE"
    name       varchar(3000)
    count     integer
  }
  ::xo::db::require index -table xowiki_autonames -col parent_id,name -unique true
  ::xo::db::require index -table xowiki_autonames -col parent_id

  ::xotcl::Object create autoname
  autoname proc generate {-parent_id -name} {
    ::xo::dc transaction {
      set already_recorded [::xo::dc 0or1row autoname_query {
        select count from xowiki_autonames
        where parent_id = :parent_id and name = :name}]

      if {$already_recorded} {
        incr count
        ::xo::dc dml update_autoname_counter \
            "update xowiki_autonames set count = count + 1 \
              where parent_id = :parent_id and name = :name"
      } else {
        set count 1
        ::xo::dc dml insert_autoname_counter \
            "insert into xowiki_autonames (parent_id, name, count) \
             values (:parent_id, :name, $count)"
      }
    }
    return $name$count
  }

  autoname proc basename {name} {
    # In case the provided name has an extension, return the name
    # without it.
    file rootname $name
  }

  autoname proc new {-parent_id -name} {
    while {1} {
      set generated_name [my generate -parent_id $parent_id -name $name]
      if {[::xo::db::CrClass lookup -name $generated_name -parent_id $parent_id] eq "0"} {
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

    ns_cache create xowiki_cache \
        -size [parameter::get_global_value \
                   -package_key xowiki \
                   -parameter CacheSize \
                   -default 400000]
  }

  #############################
  #
  # Page definitions
  #

  Page set recursion_count 0
  Page array set RE {
    include {{{([^<]+?)}}([^\}]|$)}
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
  Page instproc marshall {{-mode export}} {
    my instvar name
    my unset_temporary_instance_variables
    set old_creation_user  [my creation_user]
    set old_modifying_user [my set modifying_user]
    my set creation_user   [my map_party -property creation_user $old_creation_user]
    my set modifying_user  [my map_party -property modifying_user $old_modifying_user]
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

  File instproc marshall {{-mode export}} {
    set fn [my full_file_name]
    if {$mode eq "export"} {
      my set __file_content [::base64::encode [::xowiki::read_file $fn]]
    } else {
      my set __file_name $fn
    }
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
      lassign $category category_id category_name deprecated_p level
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
      } elseif {[$f istype "::xowiki::formfield::file"]} {
        set cm([$f name]) [list file 0]
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
      lassign $category category_id category_name deprecated_p level
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


  Form instproc marshall {{-mode export}} {
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
      return [my map_party -property $map_type $value]
    } elseif {$map_type eq "file" && [llength $value] % 2 == 0} {
      #
      # drop revision_id from file value
      #
      set result {}
      foreach {a v} $value {
        if {$a eq "revision_id"} continue
        lappend result $a $v
      }
      return $result
    } else {
      return $value
    }
  }

  FormPage instproc marshall {{-mode export}} {
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
    if {$mode eq "copy" && ![string match "*revision_id*" [my set instance_attributes]]} {
      return [next]
    }
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
      array set multiple_index [list category 2 party_id 1 file 1]
      set ia [list]
      foreach {name value} [my instance_attributes] {
        #my log "marshall check $name $value [info exists use($name)]"
        if {[info exists use($name)]} {
          set map_type [lindex $use($name) 0]
          set multiple [lindex $use($name) $multiple_index($map_type)]
          #my log "+++ marshall check $name $value use <$use($name)> m=?$multiple"
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
    my set assignee  [my map_party -property assignee $old_assignee]
    set r [next]
    my set assignee  $old_assignee
    return $r
  }

  Page instproc map_party {-property party_id} {
    #my log "+++ $party_id"
    # So far, we just handle users, but we should support parties in
    # the future as well.
    if {$party_id eq "" || $party_id == 0} {
      return $party_id
    }
    if {![catch {acs_user::get -user_id $party_id -array info}]} {
      set result [list]
      foreach a {username email first_names last_name screen_name url} {
        lappend result $a $info($a)
      }
      ns_log notice "--    map_party $party_id: $result"
      return $result
    }
    if {![catch {group::get -group_id $party_id -array info}]} {
      ns_log notice "got group info: [array get info]"
      set result [array get info]
      set members {}
      foreach member_id [group::get_members -group_id $party_id] {
        lappend members [my map_party -property $property $member_id]
      }
      lappend result members $members
      ns_log notice "--    map_party $party_id: $result"
      return $result
    }
    ns_log warning "Cannot map party_id $party_id, probably not a user; property $property lost during export"
    return {}
  }

  Page instproc reverse_map_party {-entry -default_party {-create_user_ids 0}} {
    # So far, we just handle users, but we should support parties in
    # the future as well.http://localhost:8003/nimawf/admin/export

    array set "" $entry
    if {[info exists (email)] && $(email) ne ""} {
      set id [party::get_by_email -email $(email)]
      if {$id ne ""} { return $id }
    }
    if {[info exists (username)] && $(username) ne ""} {
      set id [acs_user::get_by_username -username $(username)]
      if {$id ne ""} { return $id }
    }
    if {[info exists (group_name)] && $(group_name) ne ""} {
      set id [group::get_id -group_name $(group_name)]
      if {$id ne ""} { return $id }
    }

    if {$create_user_ids} {
      if {[info exists (group_name)] && $(group_name) ne ""} {
        my log "+++ create a new group group_name=$(group_name)"
        set group_id [group::new -group_name $(group_name)]
        array set info [list join_policy $(join_policy)]
        group::update -group_id $group_id -array info
        ns_log notice "+++ reverse_party_map: we could add members $(members) - but we don't"
        return $group_id
      } else {
        my log "+++ create a new user username=$(username), email=$(email)"
        array set status [auth::create_user -username $(username) -email $(email) \
                              -first_names $(first_names) -last_name $(last_name) \
                              -screen_name $(screen_name) -url $(url)]
        if {$status(creation_status) eq "ok"} {
          return $status(user_id)
        }
        my log "+++ create user username=${username}, email=$(email) failed, reason=$status(creation_status)"
      }
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
    set is_folder_page [my is_folder_page]
    #my msg "is-folder-page [my name] => $is_folder_page"
    if {$is_folder_page} {
      # reset names if necessary (e.g. import from old releases)
      my set name [my build_name]
    } else {
      # Check, if nls_language and lang are aligned.
      if {[regexp {^(..):} [my name] _ lang]} {
        if {[string range [my nls_language] 0 1] ne $lang} {
          set old_nls_language [my nls_language]
          my nls_language [my get_nls_language_from_lang $lang]
          ns_log notice "nls_language for item [my name] set from $old_nls_language to [my nls_language]"
        }
      }
    }
    # in the general case, no more actions required
    #my msg "demarshall [my name] DONE"
  }

  File instproc demarshall {args} {
    next
    # we have to care about recoding the file content

    if {[my exists __file_content]} {
      my instvar import_file __file_content
      set import_file [ad_tmpnam]
      ::xowiki::write_file $import_file [::base64::decode $__file_content]
      catch {my unset full_file_name}
      unset __file_content
    } elseif {[my exists __file_name]} {
      my instvar import_file __file_name
      set import_file $__file_name
      unset __file_name
    } else {
      error "either __file_content or __file_name must be set"
    }
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


  FormPage instproc reverse_map_values {-creation_user -create_user_ids map_type values category_ids_name} {
    # Apply reverse_map_value to a list of values (for multi-valued
    # form fields)
    my upvar $category_ids_name category_ids
    set mapped_values [list]
    foreach value $values {
      lappend mapped_values [my reverse_map_value \
                                 -creation_user $creation_user -create_user_ids $create_user_ids \
                                 $map_type $value category_ids]
    }
    return $mapped_values
  }

  FormPage instproc reverse_map_value {-creation_user -create_user_ids map_type value category_ids_name} {
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
      array set multiple_index [list category 2 party_id 1 file 1]
      foreach {name value} [my instance_attributes] {
        #my msg "use($name) --> [info exists use($name)]"
        if {[info exists use($name)]} {
          #my msg "try to map value '$value' (category tree: $use($name))"
          set map_type [lindex $use($name) 0]
          set multiple [lindex $use($name) $multiple_index($map_type)]
          if {$multiple eq ""} {set multiple 1}
          if {$multiple} {
            lappend ia $name [my reverse_map_values \
                                  -creation_user $creation_user -create_user_ids $create_user_ids \
                                  $map_type $value category_ids]
          } else {
            lappend ia $name [my reverse_map_value \
                                  -creation_user $creation_user -create_user_ids $create_user_ids \
                                  $map_type $value category_ids]
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
    set cmd [list $package_id import -replace $replace]

    if {[info exists user_id]}   {lappend cmd -user_id $user_id}
    if {[info exists objects]}   {lappend cmd -objects $objects}
    {*}$cmd
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
    ::xo::dc dml delete_tags \
        "delete from xowiki_tags where item_id = :item_id and user_id = :user_id"

    foreach tag [split $tags " ,;"] {
      if {$tag ne ""} {
        ::xo::dc dml insert_tag \
            "insert into xowiki_tags (item_id,package_id, user_id, tag, time) \
          values (:item_id, :package_id, :user_id, :tag, now())"
      }
    }
    search::queue -object_id $revision_id -event UPDATE
  }

  Page proc get_tags {-package_id:required -item_id -user_id} {
    if {[info exists item_id]} {
      if {[info exists user_id]} {
        # tags for item and user
        set tags [::xo::dc list get_tags {
          SELECT distinct tag from xowiki_tags
          where user_id = :user_id and item_id = :item_id and package_id = :package_id
        }]
      } else {
        # all tags for this item
        set tags [::xo::dc list get_tags {
          SELECT distinct tag from xowiki_tags
          where item_id = :item_id and package_id = :package_id
        }]
      }
    } else {
      if {[info exists user_id]} {
        # all tags for this user
        set tags [::xo::dc list get_tags {
          SELECT distinct tag from xowiki_tags
          where user_id = :user_id and package_id :package_id
        }]
      } else {
        # all tags for the package
        set tags [::xo::dc list get_tags {
          SELECT distinct tag from xowiki_tags
          where package_id = :package_id
        }]
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

  #
  # check certain properties of a page (is_* methods)
  #

  #
  # Check, if page is a folder
  #
  Page instproc is_folder_page {{-include_folder_links true}} {
    return 0
  }
  FormPage instproc is_folder_page {{-include_folder_links true}} {
    set page_template_name [[my page_template] name]
    if {$page_template_name eq "en:folder.form"} {return 1}
    if {$include_folder_links && $page_template_name eq "en:link.form"} {
      set link_type [my get_property_from_link_page link_type]
      return [expr {$link_type eq "folder_link"}]
    }
    return 0
  }

  #
  # Check, if a page is a link
  #
  Page instproc is_link_page {} {
    return 0
  }
  FormPage instproc is_link_page {} {
    return [expr {[[my page_template] name] eq "en:link.form"}]
  }

  #
  # link properties
  #
  Page instproc get_property_from_link_page {property {default ""}} {
    if {![my is_link_page]} {return $default}
    set item_ref [my property link]

    # TODO we could save some double-fetch by collecing in
    # get_form_entries via item-ids, not via new-objects
    ::xo::db::CrClass get_instance_from_db -item_id [my item_id]

    set props [::xo::cc cache [list [my item_id] compute_link_properties $item_ref]]
    array set "" $props
    if {[info exists ($property)]} {
      #[my item_id] msg "prop $property ==> $($property)"
      return $($property)
    }
    return $default
  }

  Page instproc get_target_from_link_page {{-depth 10}} {
    #
    # Dereference link and return target object of the
    # link. Dereferencing happens up to a maximal depth to avoid loop
    # in circular link structures. If this method is called with e.g.
    # {-depth 1} and the link (actual object) points to some link2,
    # the link2 is returned.
    #
    # @param depth maximal dereferencing depth
    # @return target object or empty
    #
    set item_id [my get_property_from_link_page item_id 0]
    if {$item_id == 0} {return ""}
    set target [::xo::db::CrClass get_instance_from_db -item_id $item_id]
    set target_package_id [$target package_id]
    if {$target_package_id != [my package_id]} {
      ::xowiki::Package require $target_package_id
      #::xowiki::Package initialize -package_id $target_package_id -init_url false -keep_cc true
    }
    if {$depth > 1 && [$target is_link_page]} {
      set target [my get_target_from_link_page -count [expr {$depth - 1}]]
    }
    return $target
  }

  FormPage instproc compute_link_properties {item_ref} {
    my instvar package_id
    set page [$package_id get_page_from_item_ref \
                  -default_lang [my lang] \
                  -parent_id [my parent_id] \
                  $item_ref]
    if {$page ne ""} {
      set item_id [$page item_id]
      set link_type [expr {[$page is_folder_page] ? "folder_link" : "link"}]
      set cross_package [expr {$package_id != [$page package_id]}]
    } else {
      set item_id 0
      set link_type "unresolved"
      set cross_package 0
    }
    #my msg [list item_ref $item_ref item_id $item_id link_type $link_type cross_package $cross_package]
    return [list item_ref $item_ref item_id $item_id link_type $link_type cross_package $cross_package]
  }

  #
  # Check, if a page is a form
  #

  Page instproc is_form {} {
    return 0
  }
  Form instproc is_form {} {
    return 1
  }
  FormPage instproc is_form {} {
    return [my exists_property form_constraints]
  }

  FormPage instproc hstore_attributes {} {
    # Per default, we save all instance attributes in hstore, but a
    # subclass/object might have different requirements.
    return [my instance_attributes]
  }

  #
  # Update helper for xowiki_form_instance_item_index (called from
  # cr_procs, whenever a live-revision becomes updated).
  #
  FormPage ad_instproc update_item_index {} {

    Tailored version of CrItem.update_item_index to keep
    insert_xowiki_form_instance_item_index in sync after updates.

  } {
    my instvar name item_id package_id parent_id publish_status \
        page_template instance_attributes assignee state

    set rows [xo::dc dml update_xowiki_form_instance_item_index {
      update xowiki_form_instance_item_index
      set name = :name, package_id = :package_id,
          parent_id = :parent_id, publish_status = :publish_status,
          page_template = :page_template, assignee = :assignee,
          state = :state
      where item_id = :item_id
    }]
    if {$rows ne "" && $rows < 1} {
      ::xo::dc dml insert_xowiki_form_instance_item_index {
        insert into xowiki_form_instance_item_index (
            item_id, name, package_id, parent_id, publish_status,
            page_template, assignee, state
            ) values (
            :item_id, :name, :package_id, :parent_id, :publish_status,
            :page_template, :assignee, :state
            )
      }
    }
    if {[$package_id get_parameter use_hstore 0]} {
      set hkey [::xowiki::hstore::dict_as_hkey [my hstore_attributes]]
      xo::dc dml update_hstore "update xowiki_form_instance_item_index \
                set hkey = '$hkey' \
                where item_id = :item_id"
    }
  }

  FormPage ad_instproc update_attribute_from_slot {-revision_id slot value} {

    Tailored version of update_attribute_from_slot to keep
    insert_xowiki_form_instance_item_index in sync after singe
    attribtute updates.

  } {
    #
    # perform first the regular operations
    #
    next
    #
    # Make sure to update update_item_index when the attribute is
    # contained in the xowiki_form_instance_item_index
    #
    set colName [$slot column_name]
    if {$colName in {
      package_id
      parent_id
      publish_status
      page_template
      instance_attributes
      assignee
      state
    }} {
      ::xowiki::update_item_index -item_id [my item_id] -$colName $value
    }
  }

  ad_proc update_item_index {
    -item_id:required
    -package_id
    -parent_id
    -publish_status
    -page_template
    -instance_attributes
    -assignee
    -state
    -hstore_attributes
  } {

    Helper function to update single or multiple fields of the
    xowiki_form_instance_item_index. Call this function only when
    updating fields of the xowiki_form_instance_item_index in cases
    where the standard API based on save and save_use canot be used.

  } {
    foreach var {
      package_id parent_id
      publish_status page_template
      instance_attributes assignee state
    } {
      if {[info exists $var]} {
        xo::dc dml update_xowiki_form_instance_item_index_$var [subst {
          update xowiki_form_instance_item_index
          set $var = :$var
          where item_id = :item_id
        }]
      }
    }
    if {[info exists hstore_attributes]} {
      set hkey [::xowiki::hstore::dict_as_hkey $hstore_attributes]
      xo::dc dml update_hstore "update xowiki_form_instance_item_index \
                set hkey = '$hkey' \
                where item_id = :item_id"
    }
  }

  #
  # Define a specialized version of CrClass.fetch_object based
  # on xowiki_form_instance_item_view
  #
  FormPage ad_proc fetch_object {
    -item_id:required
    {-revision_id 0}
    -object:required
    {-initialize true}
  } {
    Load a content item into the specified object. If revision_id is
    provided, the specified revision is returned, otherwise the live
    revision of the item_id. If the object does not exist, we create it.

    @return cr item object
  } {
    #
    # We handle here just loading object instances via item_id, since
    # only live_revisions are kept in xowiki_form_instance_item_index.
    # The loading via revisions happens as before in CrClass.
    #
    if {$item_id == 0} {
      return [next]
    }

    if {![::xotcl::Object isobject $object]} {
      # if the object does not yet exist, we have to create it
      my create $object
    }

    $object set item_id $item_id
    set success [$object db_0or1row [my qn fetch_from_view_item_id] {
      select * from xowiki_form_instance_item_view where item_id = :item_id
    }]
    if {$success == 0} {
      error [subst {
        The form page with item_id $item_id was not found in the xowiki_form_instance_item_index.
        Consider 'DROP TABLE xowiki_form_instance_item_index CASCADE;' and restart server
        (the table is rebuilt automatically)
      }]
    }

    if {$initialize} {$object initialize_loaded_object}
    return $object
  }

  #
  # Define a specialized version of CrItem.set_live_revision updating the item index.
  #  

  FormPage ad_instproc set_live_revision {-revision_id:required {-publish_status "ready"}} {
    @param revision_id
    @param publish_status one of 'live', 'ready' or 'production'
  } {
    next
    my update_item_index
  }

  #
  # helper for nls and lang
  #

  Page instproc lang {} {
    return [string range [my nls_language] 0 1]
  }

  Page instforward get_nls_language_from_lang ::xowiki::Package %proc

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

    #my msg "$name / '$stripped_name'"
    # prepend the language prefix only, if the entry is not empty
    if {$stripped_name ne ""} {
      if {[my is_folder_page] || [my is_link_page]} {
        #
        # Do not add a language prefix to folder pages
        #
        set name $stripped_name
      } else {
        if {$nls_language ne ""} {my nls_language $nls_language}
        set name [my lang]:$stripped_name
      }
    }
    return $name
  }

  #
  # context handling
  #
  Page instproc set_resolve_context {-package_id:required -parent_id:required -item_id} {
    if {[my set parent_id] != $parent_id} {
      my set physical_parent_id [my set parent_id]
      my set parent_id $parent_id
    }
    if {[my set package_id] != $package_id} {
      my set physical_package_id [my set package_id]
      my set package_id $package_id
      #my msg "doing extra require on [my set physical_package_id]"
      #::xowiki::Package require [my set physical_package_id]
    }
    if {[info exists item_id] && [my item_id] != $item_id} {
      my set physical_item_id [my set item_id]
      my set item_id $item_id
    }
  }
  Page instproc reset_resolve_context {} {
    foreach att {item package parent} {
      set name physical_${att}_id
      if {[my exists $name]} {
        my set ${att}_id [my set $name]
        my unset $name
      }
    }
  }

  Page instproc physical_parent_id {} {
    if {[my exists physical_parent_id]} {
      return [my set physical_parent_id]
    } else {
      return [my parent_id]
    }
  }

  Page instproc physical_package_id {} {
    if {[my exists physical_package_id]} {
      return [my set physical_package_id]
    } else {
      return [my package_id]
    }
  }

  #
  # folder handling
  #

  Page instproc get_folder {-folder_form_ids:required} {
    set page [self]
    while {1} {
      if {[$page istype ::xowiki::FormPage]} {
        if {[$page is_folder_page]} break

        #     set page_template [$page page_template]
        #     set page_template_name [$page_template name]
        #         # search the page_template in the list of form_ids
        #         if {$page_template in $folder_form_ids} {
        #           break
        #     } elseif {$page_template_name eq "en:folder.form"} {
        #       # safety belt, in case we have in different directories
        #       # diffenent en:folder.form
        #       break
        #     } elseif {$page_template_name eq "en:link.form"} {
        #       set fp [my is_folder_page]
        #       my msg fp=$fp
        #       break
        #         }
      }
      set page [::xo::db::CrClass get_instance_from_db -item_id [$page parent_id]]
    }
    return $page
  }

  #
  # save / restore
  #

  Page instproc can_contain {obj} {
    #
    # This is a stub which can / should be refined in applications,
    # which want to disallow pages (e.g. folders) to be parent of some
    # kind of content. The function should return 0 if some content is
    # not allowed.
    #
    return 1
  }

  Page instproc can_link {item_id} {
    #
    # This is a stub which can / should be refined in applications,
    # which want to disallow links to other pages, in the sense, that
    # the links are not shown at all. A sample implementation might
    # look like the follwing.
    #
    # if {$item_id ne 0} {
    #   set obj [::xo::db::CrClass get_instance_from_db -item_id $item_id]
    #   return [$obj can_be_linked]
    # }
    #
    return 1
  }

  Page instproc can_be_linked {} {
    return 1
  }

  Page instproc can_save {} {
    #
    # Determine the parent object of the page to be saved. If the
    # parent object is an page as well, then call can_contain. The
    # function is just determining a boolen value shuch it can be used
    # for testing insertability as well.
    #
    set parent [my get_parent_object]
    if {$parent ne "" && [$parent istype ::xowiki::Page]} {
      return [$parent can_contain [self]]
    }
    return 1
  }

  Page instproc save args {
    if {![my can_save]} {error "can't save this page under this parent"}
    [my package_id] flush_page_fragment_cache
    next
  }

  Page instproc save_new args {
    if {![my can_save]} {error "can't save this page under this parent"}
    [my package_id] flush_page_fragment_cache
    next
  }

  Page instproc initialize_loaded_object {} {
    my instvar title
    if {[info exists title] && $title eq ""} {set title [my set name]}
    next
  }

  #
  # misc
  #

  Page instproc get_parent_object {} {
    #
    # Obtain the parent object for a page. If the parent page is a
    # dummy entry or not an object, return empty.
    #
    set parent_id [my set parent_id]
    if {$parent_id > 0} {
      if {! [my isobject ::$parent_id] } {
        ::xo::db::CrClass get_instance_from_db -item_id $parent_id
      }
      return ::$parent_id
    }
    return ""
  }

  Page instproc get_instance_attributes {} {
    if {[my exists instance_attributes]} {
      return [my set instance_attributes]
    }
    return ""
  }

  #
  # render and substitutions
  #

  Page instproc regsub_eval {{-noquote:boolean false} re string cmd {prefix ""}} {
    if {$noquote} {
      set map { \[ \\[ \] \\] \$ \\$ \\ \\\\}
    } else {
      set map { \" \\\" \[ \\[ \] \\] \$ \\$ \\ \\\\}
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
    set package_id [my package_id]

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
      #set page [my resolve_included_page_name $page_name]
      set page [$package_id get_page_from_item_ref \
                    -use_package_path true \
                    -use_site_wide_pages true \
                    -use_prototype_pages true \
                    -default_lang [my lang] \
                    -parent_id [my parent_id] $page_name]

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
        -id {$includelet set id $value}
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
      set ::errorInfo [::xowiki::Includelet html_encode $::errorInfo]
      set html [my error_during_render [_ xowiki.error-includelet-error_during_render]]
    }
    #my log "--include includelet returns $html"
    return $html
  }

  #   Page instproc include_portlet {arg} {
  #     my log "+++ method [self proc] of [self class] is deprecated"
  #     return [my include $arg]
  #   }

  Page ad_instproc include {-configure arg} {
    Include the html of the includelet. The method generates
    an includelet object (might be an other xowiki page) and
    renders it and returns either html or an error message.
  } {
    set page [my instantiate_includelet $arg]
    if {$page eq ""} {
      # The variable 'page_name' is required by the message key
      set page_name $arg
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
      $page configure {*}$configure
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
      return "<div id='[ns_quotehtml $arg]' class='column'>"
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

  Page instforward item_ref {%my package_id} %proc

  Page instproc pretty_link {
    {-anchor ""}
    {-query ""}
    {-absolute:boolean false}
    {-siteurl ""}
    {-lang ""}
    {-download false}
  } {
    # return the pretty_link for the current page
    [my package_id] pretty_link -parent_id [my parent_id] \
        -anchor $anchor -query $query -absolute $absolute -siteurl $siteurl \
        -lang $lang -download $download [my name]
  }

  Page instproc detail_link {} {
    if {[my exists instance_attributes]} {
      set __ia [my set instance_attributes]
      if {[dict exists $__ia detail_link] && [dict get $__ia detail_link] ne ""} {
        return [dict get $__ia detail_link]
      }
    }
    return [my pretty_link]
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
            [self]::link configure {*}$options
            return [self]::link
          }
        }
      }
      set l [ExternalLink new [list -label $label] -href $link]
      $l configure {*}$options
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

    # we might consider make this configurable
    set use_package_path true
    
    if {[regexp {^:(..):(.+)$} $(link) _ lang stripped_name]} {
      # we found a language link (it starts with a ':')
      array set "" [$package_id item_ref \
                        -use_package_path $use_package_path \
                        -default_lang [my lang] \
                        -parent_id $parent_id \
                        ${lang}:$stripped_name]
      set (link_type) language
    } elseif {[regexp {^[.]SELF[.]/(.*)$} $(link) _ (link)]} {
      #
      # Remove ".SELF./" from the path and search for the named
      # resource (e.g. the image name) under the current item.
      #
      array set "" [$package_id item_ref \
                        -use_package_path $use_package_path \
                        -default_lang [my lang] \
                        -parent_id [my item_id] \
                        $(link)]
      
    } else {
      #
      # a plain link, search relative to the parent
      #
      array set "" [$package_id item_ref \
                        -use_package_path $use_package_path \
                        -default_lang [my lang] \
                        -parent_id $parent_id \
                        $(link)]
    }
      
    #my log "link '$(link)' => [array get {}]"

    if {$label eq $arg} {set label $(link)}
    set item_name [string trimleft $(prefix):$(stripped_name) :]

    Link create [self]::link \
        -page [self] -form $(form) \
        -type $(link_type) [list -name $item_name] -lang $(prefix) \
        [list -anchor $(anchor)] [list -query $(query)] \
        [list -stripped_name $(stripped_name)] [list -label $label] \
        -parent_id $(parent_id) -item_id $(item_id) -package_id $package_id

    # in case, we can't link, flush the href
    if {[my can_link $(item_id)] == 0} {
      my references refused $(item_id)
      [self]::link href ""
    }

    if {[catch {[self]::link configure {*}$options} errorMsg]} {
      ns_log error "$errorMsg\n$::errorInfo"
      return "<div class='errorMsg'>Error during processing of options [list $options]\
        of link of type [[self]::link info class]:<blockquote>$errorMsg</blockquote></div>"
    } else {
      return [self]::link
    }
  }

  Page instproc new_link {-name -title -nls_language -return_url -parent_id page_package_id} {
    if {[info exists parent_id] && $parent_id eq ""} {unset parent_id}
    return [$page_package_id make_link -with_entities 0 $page_package_id \
                edit-new object_type name title nls_language return_url parent_id autoname]
  }

  FormPage instproc new_link {-name -title -nls_language -parent_id -return_url page_package_id} {
    set template_id [my page_template]
    if {![info exists parent_id]} {set parent_id [$page_package_id folder_id]}
    set form [$page_package_id pretty_link -parent_id $parent_id [$template_id name]]
    return [$page_package_id make_link -with_entities 0 -link $form $template_id \
                create-new return_url name title nls_language]
  }

  #
  # Handling page references. Use like e.g.
  #
  #   $page references clear
  #   $page references resolved [list $item_id [my type]]
  #   $page references get resolved
  #   $page references all
  #
  Page instproc references {submethod args} {
    my instvar __references
    switch $submethod {
      clear {
        set __references { unresolved {} resolved {} refused {} }
      }
      unresolved -
      refused -
      resolved {
        return [dict lappend __references $submethod [lindex $args 0]]
      }
      get { return [dict  $submethod $__references [lindex $args 0]] }
      all { return $__references }
      default {error "unknown submethod: $submethod"}
    }
  }

  Page instproc anchor {arg} {
    if {[catch {set l [my create_link [my unescape $arg]]} errorMsg]} {
      return "<div class='errorMsg'>Error during processing of anchor ${arg}:<blockquote>$errorMsg</blockquote></div>"
    }
    if {$l eq ""} {return ""}
    set html [$l render]
    if {[info commands $l] ne ""} {
      $l destroy
    } else {
      ns_log notice "link object already destroyed. This might be due to a recurisive inclusion"
    }
    return $html
  }


  Page instproc substitute_markup {content} {

    if {[my set mime_type] eq "text/enhanced"} {
      set content [ad_enhanced_text_to_html $content]
    }
    if {![my do_substitutions]} {return $content}
    #
    # The provided content and the returned result are strings
    # containing HTML (unless we have other rich-text encodings).
    #
    # First get the right regular expression definitions
    #
    set baseclass [expr {[[my info class] exists RE] ? [my info class] : [self class]}]
    $baseclass instvar RE markupmap
    #my log "-- baseclass for RE = $baseclass"

    #
    # secondly, iterate line-wise over the text
    #
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
      if {$__v in $__ignorelist} continue
      if {[info exists $__v]} continue
      [my info class] instvar $__v
    }
    set __ignorelist [list __v __vars __l __ignorelist __varlist __references \
                          __last_includelet text item_id content lang_links]

    # set variables current_* to ease personalization
    set current_user [::xo::cc set untrusted_user_id]
    set current_url [::xo::cc url]

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
        if {$__v in $__ignorelist} continue
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
      set body [::xo::dc get_value get_description_from_syndication \
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
    #my log "-- '[my set text]'"
    lassign [my set text] html mime
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
    #my msg WidgetSpecs=[$package_id get_parameter WidgetSpecs]
    foreach {s widget_spec} [$package_id get_parameter WidgetSpecs] {
      lassign [split $s ,] page_name var_name
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
    set success [::xowiki::validate_name [self]]
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

  Page instproc references_update {references} {
    #my msg $references
    my instvar item_id
    ::xo::dc dml delete_references \
        "delete from xowiki_references where page = :item_id"
    foreach ref $references {
      lassign $ref r link_type
      ::xo::dc dml insert_reference \
          "insert into xowiki_references (reference, link_type, page) \
           values (:r,:link_type,:item_id)"
    }
  }

  Page proc container_already_rendered {field} {
    if {![info exists ::xowiki_page_item_id_rendered]} {
      return ""
    }
    #my log "--OMIT and not $field in ([join $::xowiki_page_item_id_rendered ,])"
    return "and not $field in ([join $::xowiki_page_item_id_rendered ,])"
  }

  Page instproc htmlFooter {{-content ""}} {
    my instvar package_id

    if {[my exists __no_footer]} {return ""}

    set footer ""

    if {[ns_conn isconnected]} {
      set url         "[ns_conn location][::xo::cc url]"
      set package_url "[ns_conn location][$package_id package_url]"
    }

    set tags ""
    if {[$package_id get_parameter "with_tags" 1] &&
        ![my exists_query_parameter no_tags] &&
        [::xo::cc user_id] != 0
      } {
      set tag_content [my include my-tags]
      set tag_includelet [my set __last_includelet]
      if {[$tag_includelet exists tags]} {
        set tags [$tag_includelet set tags]
      }
    } else {
      set tag_content ""
    }

    if {[$package_id get_parameter "with_digg" 0] && [info exists url]} {
      if {![info exists description]} {set description [my get_description $content]}
      append footer "<div style='float: right'>" \
          [my include [list digg -description $description -url $url]] "</div>\n"
    }

    if {[$package_id get_parameter "with_delicious" 0] && [info exists url]} {
      if {![info exists description]} {set description [my get_description $content]}
      append footer "<div style='float: right; padding-right: 10px;'>" \
          [my include [list delicious -description $description -url $url -tags $tags]] \
          "</div>\n"
    }

    if {[$package_id get_parameter "with_yahoo_publisher" 0] && [info exists package_url]} {
      set publisher [$package_id get_parameter "my_yahoo_publisher" \
                         [::xo::get_user_name [::xo::cc user_id]]]
      append footer "<div style='float: right; padding-right: 10px;'>" \
          [my include [list my-yahoo-publisher \
                           -publisher $publisher \
                           -rssurl "$package_url?rss"]] \
          "</div>\n"
    }

    if {[$package_id get_parameter "show_page_references" 1]} {
      append footer [my include my-references]
    }

    if {[$package_id get_parameter "show_per_object_categories" 1]} {
      set html [my include my-categories]
      if {$html ne ""} {
        append footer $html <br>
      }
      set categories_includelet [my set __last_includelet]
    }

    append footer $tag_content

    if {[$package_id get_parameter "with_general_comments" 0] &&
        ![my exists_query_parameter no_gc]} {
      append footer [my include my-general-comments]
    }

    if {$footer ne ""} {
      # make sure, the
      append footer "<div class='visual-clear'><!-- --></div>"
    }

    return  "<div class='item-footer'>$footer</div>\n"
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
    my references clear
    if {[my exists __extra_references]} {
      #
      # xowiki content-flow uses extra references, e.g. to forms.
      # TODO: provide a better interface for providing these kind of
      # non-link references.
      #
      foreach ref [my set __extra_references] {
        my references resolved $ref
      }
      my unset __extra_references
    }
    #
    # get page content and care about reference management
    #
    set content [my render_content]
    #
    # record references and clear it
    #
    #my msg "we have the content, update=$update_references, unresolved=[my references get unresolved]"
    if {$update_references || [llength [my references get unresolved]] > 0} {
      my references_update [lsort -unique [my references get resolved]]
    }
    #my unset -nocomplain __references
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

  #
  # The method "search_render" is called by the search indexer via
  # ::xowiki::datasource and returns HTML and the keywords for the
  # search. By defining this as a method, it is possible to define a
  # different indexer e.g. via subclassing or for each workflow. The
  # method returns a list of attribute value pairs containing "html"
  # and keywords".  Below is an example of a workflow specific search
  # content.
  #
  #   [my object] proc search_render {} {
  #        return [list html "Hello World" keywords "hello world"]
  #   }
  #
  #
  Page instproc search_render {} {
    my set __no_form_page_footer 1
    set html [my render]
    my unset __no_form_page_footer

    foreach tag {h1 h2 h3 h4 h5 b strong} {
      foreach {match words} [regexp -all -inline "<$tag>(\[^<\]+)</$tag>" $html] {
        foreach w [split $words] {
          if {$w eq ""} continue
          set word($w) 1
        }
      }
    }
    foreach tag [::xowiki::Page get_tags -package_id [my package_id] -item_id [my item_id]] {
      set word($tag) 1
    }
    #my log [list html $html keywords [array names word]]
    return [list mime text/html html $html keywords [array names word] text ""]
  }

  Page instproc record_last_visited {-user_id} {
    my instvar item_id package_id
    if {![info exists user_id]} {set user_id [::xo::cc set untrusted_user_id]}
    if {$user_id > 0} {
      # only record information for authenticated users
      set rows [xo::dc dml update_last_visisted {
        update xowiki_last_visited set time = now(), count = count + 1
        where page_id = :item_id and user_id = :user_id
      }]
      if {$rows ne "" && $rows < 1} {
        ::xo::dc dml insert_last_visisted \
            "insert into xowiki_last_visited (page_id, package_id, user_id, count, time) \
             values (:item_id, :package_id, :user_id, 1, now())"
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
    if {$name ni {langmarks fontname fontsize formatblock}} {
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
    set r [xo::HttpRequest new -url http://translate.google.com/#$from/$to/$text]
    #my msg status=[$r set status]
    if {[$r set status] eq "finished"} {
      set data [$r set data]
      #my msg data=$data
      dom parse -simple -html $data doc
      $doc documentElement root
      set n [$root selectNodes {//*[@id="result_box"]}]
      my msg "$text $from=>$to node '$n'"
      if {$n ne ""} {return [$n asText]}
    }
    util_user_message -message "Could not translate text, \
        status=[$r set status]"
    return "untranslated: $text"
  }


  Page instproc create_form_page_instance {
    -name:required
    -package_id
    -parent_id
    {-text ""}
    {-instance_attributes ""}
    {-default_variables ""}
    {-nls_language ""}
    {-creation_user ""}
    {-publish_status production}
    {-source_item_id ""}
  } {
    set ia [dict merge [my default_instance_attributes] $instance_attributes]

    if {$nls_language eq ""} {
      set nls_language [my query_parameter nls_language [my nls_language]]
    }
    if {![info exists package_id]} { set package_id [my package_id] }
    if {![info exists parent_id]}  { set parent_id [my parent_id] }
    if {$creation_user eq ""} {
      set creation_user [[$package_id context] user_id]
    }

    set f [FormPage new -destroy_on_cleanup \
               -name $name \
               -text $text \
               -package_id $package_id \
               -parent_id $parent_id \
               -nls_language $nls_language \
               -publish_status $publish_status \
               -creation_user $creation_user \
               -instance_attributes $ia \
               -page_template [my item_id]]

    if {[my exists state]} {
      $f set state [my set state]
    }

    # Make sure to load the instance attributes
    #$f array set __ia [$f instance_attributes]

    # Call the application specific initialization, when a FormPage is
    # initially created. This is used to control the life-cycle of
    # FormPages.
    $f initialize

    #
    # if we copy an item, we use source_item_id to provide defaults
    #
    if {$source_item_id ne ""} {
      set source [FormPage get_instance_from_db -item_id $source_item_id]
      $f copy_content_vars -from_object $source
      set name "[::xowiki::autoname new -parent_id $source_item_id -name [my name]]"
      $package_id get_lang_and_name -name $name lang name
      $f set name $name
      #my msg nls=[$f nls_language],source-nls=[$source nls_language]
    }
    foreach {att value} $default_variables {
      $f set $att $value
    }

    # Finally provide base for auto-titles
    $f set __title_prefix [my title]

    return $f
  }


  #
  # Methods of ::xowiki::PlainPage
  #

  PlainPage parameter {
    {render_adp 0}
  }
  PlainPage array set RE {
    include {{{(.+?)}}([^\}]|$)}
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
    if {$name ne ""} {
      set stripped_name $name
      regexp {^(.*):(.*)$} $name _ _t stripped_name
    } else {
      set stripped_name $fn
      # Internet explorer seems to transmit the full path of the
      # filename. Just use the last part in such cases as name.
      regexp {[/\\]([^/\\]+)$} $stripped_name _ stripped_name
    }
    return file:[[my package_id] normalize_name $stripped_name]
  }
  File instproc full_file_name {} {
    if {![my exists full_file_name]} {
      if {[my exists item_id]} {
        my instvar text mime_type package_id item_id revision_id
        set storage_area_key [::xo::dc get_value get_storage_key \
                                  "select storage_area_key from cr_items where item_id=:item_id"]
        my set full_file_name [cr_fs_path $storage_area_key]/$text
        #my log "--F setting FILE=[my set full_file_name]"
      }
    }
    return [my set full_file_name]
  }

  File instproc search_render {} {
    #  array set "" {mime text/html text "" html "" keywords ""}
    set mime [my set mime_type]
    if {$mime eq "text/plain"} {
      set result [next]
    } else {
      if {[info commands "::search::convert::binary_to_text"] ne ""} {
        set txt [search::convert::binary_to_text -filename [my full_file_name] -mime_type $mime]
        set result [list text $txt mime text/plain]
      } else {
        set result [list text "" mime text/plain]
      }
    }

    #ns_log notice "search_render returns $result"
    return $result
  }

  File instproc html_content {{-add_sections_to_folder_tree 0} -owner} {
    set parent_id [my parent_id]
    set fileName [my full_file_name]

    set f [open $fileName r]; set data [read $f]; close $f

    # Ugly hack to fight against a problem with tDom: asHTML strips
    # spaces between a </span> and the following <span>"
    #regsub -all "/span>      <span" $data "/span>\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;<span" data
    #regsub -all "/span>     <span" $data "/span>\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;<span" data
    #regsub -all "/span>    <span" $data "/span>\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;<span" data
    #regsub -all "/span>   <span" $data "/span>\\&nbsp;\\&nbsp;\\&nbsp;<span" data
    #regsub -all "/span>  <span" $data "/span>\\&nbsp;\\&nbsp;<span" data

    regsub -all "/span> " $data "/span>\\&nbsp;" data
    regsub -all " <span " $data "\\&nbsp;<span " data
    regsub -all "/span>\n<span " $data "/span><br><span " data
    regsub -all "/span>\n\n<span " $data "/span><br><br><span " data

    dom parse -html $data doc
    $doc documentElement root

    #
    # substitute relative links to download links in the same folder
    #
    set prefix [$parent_id pretty_link -absolute true -download true]
    foreach n [$root selectNodes //img] {
      set src [$n getAttribute src]
      if {[regexp {^[^/]} $src]} {
        $n setAttribute src $prefix/$src
        #my msg "setting src to $prefix/$src"
      }
    }

    #
    # In case, the switch is activated, and we have a menubar, add the
    # top level section
    #
    if {$add_sections_to_folder_tree && [info commands ::__xowiki__MenuBar] ne ""} {
      $owner set book_mode 1
      set pages [::xo::OrderedComposite new -destroy_on_cleanup]
      if {$add_sections_to_folder_tree == 1} {
        set selector //h2
      } else {
        set selector {//h2 | //h3}
      }

      set order 0
      foreach n [$root selectNodes $selector] {
        if {[$n hasAttribute id]} {
          set name [$n getAttribute id]
        } else {
          set name "section $n"
        }
        set o [::xotcl::Object new]
        $o set page_order [incr $order]
        $o set title [$n asText]

        set e [$doc createElement a]
        $e setAttribute name $name
        [$n parentNode] insertBefore $e $n

        $o set name $name
        $pages add $o
      }

      #$o instvar page_order title name

      ::__xowiki__MenuBar additional_sub_menu -kind folder -pages $pages -owner $owner
    }

    #
    # return content of body
    #
    set content ""
    foreach n [$root selectNodes //body/*] { append content [$n asHTML] \n }

    return $content
  }

  File instproc render_content {} {
    my instvar name mime_type description parent_id package_id item_id creation_user
    # don't require permissions here, such that rss can present the link
    #set page_link [$package_id make_link -privilege public [self] download ""]

    set ctx [$package_id context]
    set revision_id [$ctx query_parameter revision_id]
    set query [expr {$revision_id ne "" ? "revision_id=$revision_id" : ""}]
    set page_link [my pretty_link -download true -query $query]
    if {[$ctx query_parameter html-content] ne ""} {
      return [my html_content]
    }

    #my log "--F page_link=$page_link ---- "
    set t [TableWidget new -volatile \
               -columns {
                 AnchorField name -label [_ xowiki.Page-name]
                 Field mime_type -label "#xowiki.content_type#"
                 Field last_modified -label "#xowiki.Page-last_modified#"
                 Field mod_user -label "#xowiki.By_user#"
                 Field size -label "#xowiki.Size# (Bytes)"
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

    switch -glob $mime_type {
      image/* {
        set l [Link new \
                   -page [self] -query $query \
                   -type image -name $name -lang "" \
                   -stripped_name $stripped_name -label $label \
                   -parent_id $parent_id -item_id $item_id -package_id $package_id]
        set preview "<div >[$l render]</div>"
        $l destroy
      }
      text/plain {
        set text [::xowiki::read_file [my full_file_name]]
        set preview "<pre class='code'>[::xowiki::Includelet html_encode $text]</pre>"
      }
      default {set preview ""}
    }
    return "$preview[$t asHTML]\n<p>$description</p>"
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
  PageTemplate instproc count_usages {
    {-package_id 0}
    {-parent_id 0}
    {-publish_status ready}
  } {
    return [::xowiki::PageTemplate count_usages -package_id $package_id -parent_id $parent_id \
                -item_id [my item_id] -publish_status $publish_status]
  }

  PageTemplate proc count_usages {
                                  {-package_id:integer 0}
                                  {-parent_id:integer 0}
                                  -item_id:required
                                  {-publish_status ready}
                                } {
    set publish_status_clause [::xowiki::Includelet publish_status_clause -base_table i $publish_status]
    if {$package_id} {
      set bt "xowiki_page_instancei"
      set package_clause "and object_package_id = :package_id"
    } else {
      set bt "xowiki_page_instance"
      set package_clause ""
    }
    if {$parent_id} {
      set parent_id_clause "and parent_id = :parent_id"
    } else {
      set parent_id_clause ""
    }
    set count [::xo::dc get_value count_usages \
                   "select count(page_instance_id) from $bt, cr_items i  \
            where page_template = $item_id \
                        $publish_status_clause $package_clause $parent_id_clause \
                        and page_instance_id = coalesce(i.live_revision,i.latest_revision)"]
    return $count
  }

  Page instproc css_class_name {{-margin_form:boolean true}} {
    # Determine the CSS class name for xowiki forms
    #
    # We need this acually only for PageTemplate and FormPage, but
    # aliases will require XOTcl 2.0.... so we define it for the time
    # being on ::xowiki::Page
    if {[parameter::get_global_value -package_key xowiki -parameter PreferredCSSToolkit -default yui] ne "bootstrap"} {
      set name [expr {$margin_form ? "margin-form " : ""}]
    } else {
      set name ""
    }
    set CSSname [my name]

    # Remove language prefix, if used.
    regexp {^..:(.*)$} $CSSname _ CSSname

    # Remove "file extension", since dot's in CSS class names do not
    # make much sense.
    regsub {[.].*$} $CSSname "" CSSname
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
    #my msg "fc of [self] [my name] = $form_constraints"
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
    my instvar package_id
    foreach {s widget_spec} [$package_id get_parameter WidgetSpecs] {
      lassign [split $s ,] template_name var_name
      #ns_log notice "--w template_name $template_name, given '$given_template_name' varname=$var_name name=$name"
      if {([string match $template_name $given_template_name] || $given_template_name eq "") &&
          [string match $var_name $name]} {
        #ns_log notice "--w using $widget_spec for $name"
        return $widget_spec
      }
    }
    return ""
  }

  PageInstance instproc get_field_type {name default_spec} {
    #my log "--w"
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

  FormPage instproc get_anon_instances {} {
    # maybe overloaded from WorkFlow
    my get_from_template anon_instances f
  }

  FormPage instproc get_form_constraints {{-trylocal false}} {
    # We define it as a method to ease overloading.
    #my msg "is_form=[my is_form]"
    if {$trylocal && [my is_form]} {
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
    set form_obj [my get_template_object]
    #my msg "get $var from template form_obj=$form_obj [$form_obj info class]"

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
      #my msg "returning property $var from parent formpage $form_obj => '[$form_obj property $var $default]'"
      return [$form_obj property $var $default]
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
    #my msg "resolve local property $var=>[my exists_property $var]"
    if {[my istype ::xowiki::FormPage] && [my exists_property $var]} {
      #my msg "returning local property [my property $var]"
      return [my property $var]
    }
    #
    # if everything fails, return the default.
    #
    #my msg "returning the default <$default>, parent is of type [$form_obj info class]"
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
    # and add extra variables from instance attributes
    set __ia [dict merge [my template_vars $content] [my set instance_attributes]]

    foreach var [dict keys $__ia] {
      #my log "-- set $var [list $__ia($var)]"
      # TODO: just for the lookup, whether a field is a richt text field,
      # there should be a more efficient and easier way...
      if {[string match "richtext*" [my get_field_type $var text]]} {
        # ignore the text/html info from htmlarea
        set value [lindex [dict get $__ia $var] 0]
      } else {
        set value [dict get $__ia $var]
      }
      # the value might not be from the form attributes (e.g. title), don't clear it.
      if {$value eq "" && [my exists $var]} continue
      my set $var [my get_field_label $var $value]
    }
    next
  }

  PageInstance instproc count_usages {
    {-package_id 0}
    {-parent_id:integer 0}
    {-publish_status ready}
  } {
    return [::xowiki::PageTemplate count_usages -package_id $package_id \
                -parent_id $parent_id -item_id [my item_id] -publish_status $publish_status]
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
    if {[parameter::get_global_value -package_key xowiki -parameter PreferredCSSToolkit -default yui] ne "bootstrap"} {
      Form add_dom_attribute_value $form class "margin-form"
    }
    return [$root asHTML]
  }

  Form proc add_dom_attribute_value {dom_node attr value} {
    if {[$dom_node hasAttribute $attr]} {
      set old_value [$dom_node getAttribute $attr]
      if {$value ni $old_value} {
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
      lassign [my set text] html mime
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

  Page instproc default_instance_attributes {} {
    #
    # Provide the default list of instance attributes to derived
    # FormPages.
    #
    # We want to be able to create FormPages from all pages.
    # by defining this method, we allow derived applications
    # to provide their own set of instance attributes
    return [list]
  }

  #
  # Methods of ::xowiki::FormPage
  #
  FormPage instproc initialize_loaded_object {} {
    #my msg "[my name] [my info class]"
    if {[my exists page_template]} {
      set p [::xo::db::CrClass get_instance_from_db -item_id [my page_template]]
      #
      # The Form might come from a different package type (e.g. a
      # workflow) make sure, the source package is available.
      #
      # Note, that global pages (site_wide_pages) might not belong to
      # a package and have therefore an empty package_id.
      #
      set package_id [$p package_id]
      if {$package_id ne ""} {
        ::xo::Package require $package_id
      }
    }
    #my array set __ia [my instance_attributes]
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

  FormPage proc filter_expression {
                                   {-sql true}
                                   input_expr
                                   logical_op
                                 } {
    array set tcl_op {= eq < < > > >= >= <= <=}
    array set sql_op {= =  < < > > >= >= <= <=}
    array set op_map {contains,sql {$lhs_var like '%$rhs%'} contains,tcl {{$rhs} in $lhs_var}}
    #my msg unless=$unless
    #example for unless: wf_current_state = closed|accepted || x = 1
    set tcl_clause [list]
    set h_clause [list]
    set vars [list]
    set sql_clause [list]
    foreach clause [split [string map [list $logical_op \x00] $input_expr] \x00] {
      if {[regexp {^(.*[^<>])\s*([=<>]|<=|>=|contains)\s*([^=]?.*)$} $clause _ lhs op rhs_expr]} {
        set lhs [string trim $lhs]
        set rhs_expr [string trim $rhs_expr]
        if {[string range $lhs 0 0] eq "_"} {
          set lhs_var [string range $lhs 1 end]
          set rhs [split $rhs_expr |]
          if {[info exists op_map($op,sql)]} {
            lappend sql_clause [subst -nocommands $op_map($op,sql)]
            if {[my exists $lhs_var]} {
              set lhs_var "\[my set $lhs_var\]"
              lappend tcl_clause [subst -nocommands $op_map($op,tcl)]
            } else {
              my msg "ignoring unknown variable $lhs_var in expression"
            }
          } elseif {[llength $rhs]>1} {
            lappend sql_clause "$lhs_var in ('[join $rhs ',']')"
            # the following statement is only needed, when we rely on tcl-only
            lappend tcl_clause "\[lsearch -exact {$rhs} \[my property $lhs\]\] > -1"
          } else {
            lappend sql_clause "$lhs_var $sql_op($op) '$rhs'"
            # the following statement is only needed, when we rely on tcl-only
            lappend tcl_clause "\[my property $lhs\] $tcl_op($op) {$rhs}"
          }
        } else {
          set hleft [::xowiki::hstore::double_quote $lhs]
          lappend vars $lhs ""
          if {$op eq "contains"} {
            #make approximate query
            set lhs_var instance_attributes
            set rhs $rhs_expr
            lappend sql_clause [subst -nocommands $op_map($op,sql)]
          }
          set lhs_var "\[dict get \$__ia $lhs\]"
          foreach rhs [split $rhs_expr |] {
            if {[info exists op_map($op,tcl)]} {
              lappend tcl_clause [subst -nocommands $op_map($op,tcl)]
            } else {
              lappend tcl_clause "$lhs_var $tcl_op($op) {$rhs}"
            }
            if {$op eq "="} {
              # TODO: think about a solution for other operators with
              # hstore maybe: extracting it by a query via hstore and
              # compare in plain SQL
              lappend h_clause "$hleft=>[::xowiki::hstore::double_quote $rhs]"
            }
          }
        }
      } else {
        my msg "ignoring $clause"
      }
    }
    if {[llength $tcl_clause] == 0} {set tcl_clause [list true]}
    #my msg sql=$sql_clause,tcl=$tcl_clause
    return [list tcl [join $tcl_clause $logical_op] h [join $h_clause ,] \
                vars $vars sql $sql_clause]
    #my msg $expression
  }

  FormPage proc get_form_entries {
                                  -base_item_ids:required
                                  -package_id:required
                                  -form_fields:required
                                  {-publish_status ready}
                                  {-parent_id "*"}
                                  {-extra_where_clause ""}
                                  {-h_where {tcl true h "" vars "" sql ""}}
                                  {-always_queried_attributes ""}
                                  {-orderby ""}
                                  {-page_size 20}
                                  {-page_number ""}
                                  {-initialize true}
                                  {-from_package_ids ""}
                                } {
    #
    # Get query attributes for all tables (to allow e.g. sorting by time)
    #
    # The basic essential fields item_id, name, object_type and
    # publish_status are always automatically fetched from the
    # instance_select_query. Add the query attributes, we want to
    # obtain as well automatically.
    #
    # "-parent_id *"  means to get instances, regardless of
    # parent_id. Under the assumption, page_template constrains
    # the query enough to make it fast...
    #
    # "-from_package_ids {}" means get pages from the instance
    # provided via package_id, "*" means from all
    # packages. Forthermore, a list of package_ids can be given.
    #
    # "-always_queried_attributes *" means to obtain enough attributes
    # to allow a save operatons etc. on the instances.
    #

    set sql_atts {
      item_id name publish_status object_type
      parent_id revision_id instance_attributes
      creation_date creation_user last_modified
      package_id title page_template state assignee
    }

    if {$always_queried_attributes eq "*"} {
      lappend sql_atts \
          object_type object_id \
          description publish_date mime_type nls_language text \
          creator page_order page_id \
          page_instance_id xowiki_form_page_id
    } else {
      foreach att $always_queried_attributes {
        set name [string range $att 1 end]
        lappend sql_atts $name
      }
    }

    #
    # Compute the list of field_names from the already covered sql
    # attributes
    #
    set covered_attributes [list _name _publish_status _item_id _object_type]
    foreach att $sql_atts {
      #regexp {[.]([^ ]+)} $att _ name
      lappend covered_attributes _$att
    }

    #
    # Collect SQL attributes from form_fields
    #
    foreach f $form_fields {
      if {![$f exists __base_field]} continue
      set field_name [$f name]
      if {$field_name in $covered_attributes} {
        continue
      }
      lappend sql_atts [$f set __base_field]
    }
    #my msg sql_atts=$sql_atts

    #
    # Build parts of WHERE clause
    #
    set publish_status_clause [::xowiki::Includelet publish_status_clause \
                                   -base_table "" $publish_status]
    #
    # Build filter clause (uses hstore if configured)
    #
    set filter_clause ""
    array set wc $h_where
    set use_hstore [expr {[::xo::dc has_hstore] &&
                          [$package_id get_parameter use_hstore 0]
                        }]
    if {$use_hstore && $wc(h) ne ""} {
      set filter_clause " and '$wc(h)' <@ hkey"
    }
    #my msg "exists sql=[info exists wc(sql)]"
    if {$wc(sql) ne "" && $wc(h) ne ""} {
      foreach filter $wc(sql) {
        append filter_clause "and $filter"
      }
    }
    #my msg filter_clause=$filter_clause

    #
    # Build package clause
    #
    if {$from_package_ids eq ""} {
      set package_clause "and package_id = :package_id"
    } elseif {$from_package_ids eq "*"} {
      set package_clause ""
    } elseif {[llength $from_package_ids] == 1} {
      set package_clause "and package_id = :from_package_ids"
    } else {
      set package_clause "and package_id in ([join $from_package_ids ,])"
    }

    if {$parent_id eq "*"} {
      # instance_select_query expects "" for all parents, but for the semantics
      # of this method, "*" looks more appropriate
      set parent_id ""
    }

    set parent_clause ""
    if {$parent_id ne ""} {
      set parent_clause " and parent_id = :parent_id"
    }

    if {[llength $base_item_ids] == 0} {
      error "base_item_ids must not be empty"
    }
    #
    # transform all into an SQL query
    #
    if {$page_number ne ""} {
      set limit $page_size
      set offset [expr {$page_size*($page_number-1)}]
    } else {
      set limit ""
      set offset ""
    }
    set sql [::xo::dc select \
                 -vars [join $sql_atts ", "] \
                 -from xowiki_form_instance_item_view \
                 -where " page_template in ([join $base_item_ids ,]) \
            $publish_status_clause $filter_clause $package_clause $parent_clause \
            $extra_where_clause" \
                 -orderby $orderby \
                 -limit $limit -offset $offset]
    #ns_log notice "NEW SQL:\n\n$sql\n"

    #
    # When we query all attributes, we return objects named after the
    # item_id (like for single fetches)
    #
    set named_objects [expr {$always_queried_attributes eq "*"}]
    set items [::xowiki::FormPage instantiate_objects -sql $sql \
                   -named_objects $named_objects -object_named_after "item_id" \
                   -object_class ::xowiki::FormPage -initialize $initialize]

    if {!$use_hstore && $wc(tcl) != "true"} {
      # Make sure, that the expr method is available;
      # in xotcl 2.0 this will not be needed
      ::xotcl::alias ::xowiki::FormPage expr -objscope ::expr

      set init_vars $wc(vars)
      foreach p [$items children] {
        set __ia [dict merge $init_vars [$p instance_attributes]]
        if {![$p expr $wc(tcl)]} {$items delete $p}
      }
    }
    return $items
  }

  FormPage proc get_folder_children {
                                     -folder_id:required
                                     {-publish_status ready}
                                     {-object_types {::xowiki::Page ::xowiki::Form ::xowiki::FormPage}}
                                     {-extra_where_clause true}
                                   } {
    set publish_status_clause [::xowiki::Includelet publish_status_clause $publish_status]
    set result [::xo::OrderedComposite new -destroy_on_cleanup]

    foreach object_type $object_types {
      set attributes [list revision_id creation_user title parent_id page_order \
                          "to_char(last_modified,'YYYY-MM-DD HH24:MI') as last_modified" ]
      set base_table [$object_type set table_name]i
      if {$object_type eq "::xowiki::FormPage"} {
        set attributes "* $attributes"
      }
      set items [$object_type get_instances_from_db \
                     -folder_id $folder_id \
                     -with_subtypes false \
                     -select_attributes $attributes \
                     -where_clause "$extra_where_clause $publish_status_clause" \
                     -base_table $base_table]

      foreach i [$items children] {
        $result add $i
      }
    }
    return $result
  }

  FormPage proc get_super_folders {package_id folder_id {aggregated_folder_refs ""}} {
    #
    # Compute the set of folder_refs configured in the referenced
    # folders.  Get first the folder_refs configured in the actual
    # folder, which are not yet in aggregated_folder_refs.
    #
    set additional_folder_refs ""
    set folder [::xo::db::CrClass get_instance_from_db -item_id $folder_id -revision_id 0]
    if {[$folder istype ::xowiki::FormPage]} {
      foreach ref [$folder property inherit_folders] {
        if {$ref ni $aggregated_folder_refs} {lappend additional_folder_refs $ref}
      }
    }
    #
    # Process the computed additional folder refs recursively to obtain
    # the transitive set of configured item_refs (pointing to folders).
    #
    lappend aggregated_folder_refs {*}$additional_folder_refs
    foreach item_ref $additional_folder_refs {
      set page [$package_id get_page_from_item_ref $item_ref]
      if {$page eq ""} {error "configured inherited folder $item_ref cannot be resolved"}
      set aggregated_folder_refs \
          [FormPage get_super_folders $package_id [$page item_id] $aggregated_folder_refs]
    }
    return $aggregated_folder_refs
  }

  FormPage proc get_all_children {
                                  -folder_id:required
                                  {-publish_status ready}
                                  {-object_types {::xowiki::Page ::xowiki::Form ::xowiki::FormPage}}
                                  {-extra_where_clause true}
                                } {

    set folder [::xo::db::CrClass get_instance_from_db -item_id $folder_id -revision_id 0]
    set package_id [$folder package_id]

    set publish_status_clause [::xowiki::Includelet publish_status_clause $publish_status]
    set result [::xo::OrderedComposite new -destroy_on_cleanup]
    $result set folder_ids ""

    set list_of_folders [list $folder_id]
    set inherit_folders [FormPage get_super_folders $package_id $folder_id]
    my log inherit_folders=$inherit_folders

    foreach item_ref $inherit_folders {
      set folder [::xo::cc cache [list $package_id get_page_from_item_ref $item_ref]]
      if {$folder eq ""} {
        my log "Error: Could not resolve parameter folder page '$item_ref' of FormPage [self]."
      } else {
        lappend list_of_folders [$folder item_id]
      }
    }

    $result set folder_ids $list_of_folders

    foreach folder_id $list_of_folders {
      foreach object_type $object_types {
        set attributes [list revision_id creation_user title parent_id page_order \
                            "to_char(last_modified,'YYYY-MM-DD HH24:MI') as last_modified" ]
        set base_table [$object_type set table_name]i
        if {$object_type eq "::xowiki::FormPage"} {
          set attributes "* $attributes"
        }
        set items [$object_type get_instances_from_db \
                       -folder_id $folder_id \
                       -with_subtypes false \
                       -select_attributes $attributes \
                       -where_clause "$extra_where_clause $publish_status_clause" \
                       -base_table $base_table]

        foreach i [$items children] {
          $result add $i
        }
      }
    }
    return $result
  }

  # part of the code copied from Package->get_parameter
  # see xowiki/www/prototypes/folder.form.page
  FormPage instproc get_parameter {attribute {default ""}} {
    # TODO: check whether the following comment applies here
    # Try to get the parameter from the parameter_page.  We have to
    # be very cautious here to avoid recursive calls (e.g. when
    # resolve_page_name needs as well parameters such as
    # use_connection_locale or subst_blank_in_name, etc.).
    #
    set value ""
    set pp [my property ParameterPages]
    if {$pp ne {}} {
      if {![regexp {/?..:} $pp]} {
        my log "Error: Name of parameter page '$pp' of FormPage [self] must contain a language prefix"
      } else {
        set page [::xo::cc cache [list [my package_id] get_page_from_item_ref $pp]]
        if {$page eq ""} {
          my log "Error: Could not resolve parameter page '$pp' of FormPage [self]."
        }

        if {$page ne "" && [$page exists instance_attributes]} {
          set __ia [$page set instance_attributes]
          if {[dict exists $__ia $attribute]} {
            set value [dict get $__ia $attribute]
          }
        }
      }
    }


    if {$value eq {}} {set value [next $attribute $default]}
    return $value
  }

  #
  # begin property management
  #

  #FormPage instproc property_key {name} {
  #  if {[regexp {^_([^_].*)$} $name _ varname]} {
  #    return $varname
  #  } {
  #    return __ia($name)
  #  }
  #}

  FormPage instproc exists_property {name} {
    if {[regexp {^_([^_].*)$} $name _ varname]} {
      return [my exists $varname]
    }
    my instvar instance_attributes
    return [dict exists $instance_attributes $name]
  }

  FormPage instproc property {name {default ""}} {

    if {[regexp {^_([^_].*)$} $name _ varname]} {
      if {[my exists $varname]} {
        return [my set $varname]
      }
      return $default
    }

    my instvar instance_attributes
    if {[dict exists $instance_attributes $name]} {
      return [dict get $instance_attributes $name]
    }
    return $default
  }

  FormPage instproc set_property {{-new 0} name value} {
    if {[string match "_*" $name]} {
      set key [string range $name 1 end]

      if {!$new && ![my exists $key]} {
        error "property '$name' ($key) does not exist. \
        you might use flag '-new 1' for set_property to create new properties"
      }
      my set $key $value

    } else {

      my instvar instance_attributes
      if {!$new && ![dict exists $instance_attributes $name]} {
        error "property '$name' does not exist. \
        you might use flag '-new 1' for set_property to create new properties"
      }
      dict set instance_attributes $name $value
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
    lassign $value property_name op property_value
    if {![info exists property_value]} {return 0}

    #my log "$value => [my adp_subst $value]"
    array set wc [::xowiki::FormPage filter_expression [my adp_subst $value] &&]
    #my log "wc= [array get wc]"
    set __ia [dict merge $wc(vars) [my instance_attributes]]
    #my log "expr $wc(tcl) returns => [expr $wc(tcl)]"
    return [expr $wc(tcl)]
  }

  #
  # end property management
  #

  FormPage instproc set_publish_status {value} {
    if {$value ni {production ready}} {
      error "invalid value '$value'; use 'production' or 'ready'"
    }
    my set publish_status $value
  }

  FormPage instproc footer {} {
    if {[my exists __no_form_page_footer]} {
      next
    } else {
      set is_form [my property is_form__ 0]
      if {[my is_form]} {
        return [my include [list form-menu -form_item_id [my item_id] \
                                -buttons [list new answers [list form [my page_template]]]]]
      } else {
        return [my include [list form-menu -form_item_id [my page_template] -buttons form]]
      }
    }
  }


  #   FormPage instproc form_attributes {} {
  #     my log "DEPRECATRED, use 'field_names_from_form' instead "
  #     return [my field_names_from_form]
  #   }

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
        if {$var ni $allvars && $var ni $field_names} {
          lappend field_names $var
        }
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
        if {$att ni $field_names} { lappend field_names $att }
      }
      set from_HTML_form 1
    }
    return [list $from_HTML_form $field_names]
  }

  Page instproc render_icon {} {
    return [list text [namespace tail [my info class]] is_richtext false]
  }

  File instproc render_icon {} {
    return [list text "<img src='/resources/file-storage/file.gif' width='12' alt='file'>" is_richtext true]
  }

  FormPage instproc render_icon {} {
    set page_template [my page_template]
    if {[$page_template istype ::xowiki::FormPage]} {
      return [list text [$page_template property icon_markup] is_richtext true]
    }
    switch [$page_template name] {
      en:folder.form {
        return [list text "<img src='/resources/file-storage/folder.gif' width='12' alt='folder'>" is_richtext true]
      }
      en:link.form {
        set link_type [my get_property_from_link_page link_type "unresolved"]
        set link_icon "http://www.ejoe.at/typo3/sysext/rtehtmlarea/res/accessibilityicons/img/internal_link.gif"
        if {$link_type eq "unresolved"} {
          return [list text "<img src='[ns_quotehtml $link_icon]' width='12' alt='internal-link'> \
        <img src='http://www.deeptrawl.com/images/icons/brokenLinks.png' width='15'>" is_richtext true]
        }
        if {$link_type eq "folder_link"} {
          return [list text "<img src='[ns_quotehtml $link_icon]' width='12' alt='folder-link'> \
          <img src='/resources/file-storage/folder.gif' width='12' alt='folder'>" is_richtext true]
        }
        return [list text "<img src='[ns_quotehtml $link_icon]' width='12' alt='interal-link'>" is_richtext true]
      }
      default {
        return [list text [$page_template title] is_richtext false]
      }
    }
  }

  Page instproc pretty_name {} {
    return [my name]
  }

  FormPage instproc pretty_name {} {
    set anon_instances [my get_from_template anon_instances f]
    if {$anon_instances} {
      return [my title]
    }
    return [my name]
  }

  File instproc pretty_name {} {
    set name [my name]
    regsub {^file:} $name "" name
    return $name
  }

  FormPage instproc include_header_info {{-prefix ""} {-js ""} {-css ""}} {
    if {$css eq ""} {set css [my get_from_template ${prefix}_css]}
    if {$js eq ""}  {set js [my get_from_template ${prefix}_js]}
    foreach line [split $js \n] {::xo::Page requireJS [string trim $line]}
    foreach line [split $css \n] {
      set line [string trim $line]
      set order 1
      if {[llength $line]>1} {
        set e1 [lindex $line 0]
        if {[string is integer -strict $e1]} {
          set order $e1
          set line [lindex $line 1]
        }
      }
      ::xo::Page requireCSS -order $order $line
    }
  }

  FormPage instproc render_content {} {
    my instvar doc root package_id page_template
    my include_header_info -prefix form_view
    if {[::xo::cc mobile]} {my include_header_info -prefix mobile}

    set text [my get_from_template text]
    if {$text ne ""} {
      catch {set text [lindex $text 0]}
    }
    if {$text ne ""} {
      #my log "we have a template text='$text'"
      # we have a template
      return [next]
    } else {
      #my log "we have a form '[my get_form]'"
      set form [my get_form]
      if {$form eq ""} {return ""}

      my setCSSDefaults

      lassign [my field_names_from_form -form $form] form_vars field_names
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

      my log "render-content"
      Form add_dom_attribute_value $form_node role form
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
    # its pretty value in variable substitution.
    #
    # We check for special variable names here (such as current_user
    # or current_url). We provide a value from the current connection
    # context.
    if {$varname eq "current_user"} {
      set value [::xo::cc set untrusted_user_id]
    } elseif {$varname eq "current_url"} {
      set value [::xo::cc url]
    } else {
      #
      # First check to find an existing form-field with that name
      #
      set f [::xowiki::formfield::FormField get_from_name [self] $varname]
      if {$f ne ""} {
        #
        # the form field exists already, we just fill in the actual
        # value (needed e.g. in weblogs, when the same form field is
        # used for multiple page instances in a single request)
        #
        set value [$f value [my property $varname]]
      } else {
        #
        # create a form-field from scratch
        #
        set value [my property $varname]
        set f [my create_form_field -cr_field_spec $cr_field_spec -field_spec $field_spec $varname]
        $f value $value
      }

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

  FormPage instproc group_require {} {
    #
    # Create a group if necessary associated to the current form
    # page. Since the group_names are global, the group name contains
    # the parent_id of the FormPage.
    #
    set group_name "fpg-[my parent_id]-[my name]"
    set group_id [group::get_id -group_name $group_name]
    if {$group_id eq ""} {
      # group::new does not flush the chash - sigh!  Therefore we have
      # to flush the old cache entry here manually.
      ns_cache flush util_memoize \
          "group::get_id_not_cached -group_name $group_name -subsite_id {} -application_group_id {}"
      set group_id [group::new -group_name $group_name]
    }
    return $group_id
  }

  FormPage instproc group_assign {
    -group_id:integer,required
    -members:required
    {-rel_type membership_rel}
    {-member_state ""}
  } {
    set old_members [group::get_members -group_id $group_id]
    foreach m $members {
      if {$m ni $old_members} {
        #my msg "we have to add $m"
        group::add_member -group_id $group_id -user_id $m \
            -rel_type $rel_type -member_state $member_state
      }
    }
    foreach m $old_members {
      if {$m ni $members} {
        #my msg "we have to remove $m"
        group::remove_member -group_id $group_id -user_id $m
      }
    }
  }


  Page instproc is_new_entry {old_name} {
    return [expr {[my publish_status] eq "production" && $old_name eq [my revision_id]}]
  }

  Page instproc unset_temporary_instance_variables {} {
    # don't marshall/save/cache the following vars
    #my array unset __ia
    my array unset __field_in_form
    my array unset __field_needed
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

    ::xo::dc transaction {
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

      #
      # Handle now further database operations that should be saved in
      # a transaction. Examples are calender-items defined in a
      # FormPage, that should show up in the calender.
      #
      # Problably, categories should also be moved into the
      # transaction queue.
      #
      set queue ::__xowiki__transaction_queue([my item_id])
      if {[info exists $queue]} {
        foreach cmd [set $queue] {
          #ns_log notice ".... executing transaction command: $cmd"
          {*}$cmd
        }
      }

      my save -use_given_publish_date $use_given_publish_date
      if {$old_name ne $name} {
        $package_id flush_name_cache -name $old_name -parent_id [my parent_id]
        my rename -old_name $old_name -new_name $name
      }
    }
    return [my item_id]
  }

}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
