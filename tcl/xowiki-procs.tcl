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
    ad_log error "XOTcl 1.5 or newer is required. You seem to use XOTcl $::xotcl::version!"
  }

  ::xo::db::CrClass create PlainPage -superclass Page \
      -pretty_name "#xowiki.PlainPage_pretty_name#" -pretty_plural "#xowiki.PlainPage_pretty_plural#" \
      -table_name "xowiki_plain_page" -id_column "ppage_id" \
      -mime_type text/plain \
      -form ::xowiki::PlainWikiForm

  ::xo::db::CrClass create File -superclass Page \
      -pretty_name "#xowiki.File_pretty_name#" -pretty_plural "#xowiki.File_pretty_plural#" \
      -table_name "xowiki_file" -id_column "file_id" \
      -non_cached_instance_var_patterns {import_file do_substitutions} \
      -storage_type file \
      -form ::xowiki::FileForm \
      -parameter {
        {storage_type file}
      }

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
            -references "cr_items(item_id) DEFERRABLE INITIALLY DEFERRED"
        ::xo::db::CrAttribute create instance_attributes \
            -sqltype long_text \
            -default ""
        #
        # To enable hstore for xowiki/xowf, for pre-existing
        # xowiki/xowf instancs, make sure, hstore is installed in your
        # PostgreSQL installation, e.g. via
        #
        #      $PGBIN/psql -U nsadmin -d oacs-head -tAc "create extension hstore"
        #
        # Then the condition [::xo::dc has_hstore] will be true and
        # hstore can be used in principle. During startup, xowiki will
        # create indices for the hkey column on
        #
        #   - xowiki_page_instance(hkey) and
        #   - xowiki_form_instance_item_index(hkey).
        #
        # The OpenACS content repository requires updates for its
        # automatically created views und update procs. This can be done via
        #
        #    xo::db::sql::content_type refresh_view -content_type ::xowiki::PageInstance
        #    xo::db::sql::content_type refresh_view -content_type ::xowiki::FormPage
        #
        # In order to use it for certain xowf/xowiki instances, set
        # the package parameter "use_hstore" of the xowiki/xowf
        # instances that want to use hstore to 1.
        #
        # To update all hkey attributes in e.g. a package mounted at /xowf
        # use:
        #
        #     ::xo::Package initialize -url /xowiki
        #     ::xowiki::hstore::update_hstore $package_id
        #     ::xowiki::hstore::update_form_instance_item_index -package_id $package_id
        #
        # The first update command updates xowiki_page_instance, the second
        # xowiki_form_instance_item_index.
        #
        if {[::xo::dc has_hstore]} {
          ::xo::db::CrAttribute create hkey \
              -sqltype hstore \
              -default ""
        }
      } \
      -form ::xowiki::PageInstanceForm \
      -edit_form ::xowiki::PageInstanceEditForm

  if {[::xo::dc has_hstore]} {
    ::xo::db::require index -table xowiki_page_instance -col hkey -using gist
  }

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
      -non_cached_instance_var_patterns {__*} \
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

  ::xo::db::require table xowiki_unresolved_references [subst {
    page        {integer references cr_items(item_id) on delete cascade}
    parent_id   {integer references cr_items(item_id) on delete cascade}
    name        {[::xo::dc map_datatype text]}
    link_type   {[::xo::dc map_datatype text]}
  }]
  ::xo::db::require index -table xowiki_unresolved_references -col page
  ::xo::db::require index -table xowiki_unresolved_references -col parent_id
  ::xo::db::require index -table xowiki_unresolved_references -col name,parent_id

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


  # Oracle has a limit of 3118 characters for keys, therefore, we
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
  #   In order to get rid of the helper table
  #   "xowiki_form_instance_item_index", one may drop it, such it will
  #   be regenerated on the next load, but this make some time
  #   depending on the size of the instance:
  #
  #       drop table xowiki_form_instance_item_index cascade;
  #
  #
  #ns_logctl severity Debug(sql) on

  #
  # Create and populate xowiki_form_instance_item_index, when it does
  # not exist.
  #

  set populate {
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
    #
    # Create table "xowiki_form_instance_item_index" with hstore column
    #
    # If the table does not exist, we have first to populate it, and
    # at the time, when all libraries are loaded, we have to update
    # the hkeys.
    nsv_set xowiki must_update_hkeys \
        [expr {[::xo::db::require exists_table xowiki_form_instance_item_index] == 0}]

    ::xo::db::require table xowiki_form_instance_item_index [subst {
      item_id             {integer references cr_items(item_id) on delete cascade}
      name                {character varying(400)}
      package_id          {integer}
      parent_id           {integer references cr_items(item_id) on delete cascade}
      publish_status      {character varying(40)}
      page_template       {integer references cr_items(item_id) on delete cascade}
      hkey                {hstore}
      assignee            {integer references parties(party_id) on delete cascade}
      state               {[::xo::dc map_datatype text]}
    }] $populate

    ::xo::db::require index -table xowiki_form_instance_item_index -col hkey -using gist

    set hkey_in_view "xi.hkey,"
  } else {
    #
    # Create table "xowiki_form_instance_item_index" without hstore column
    #
    ::xo::db::require table xowiki_form_instance_item_index [subst {
      item_id             {integer references cr_items(item_id) on delete cascade}
      name                {character varying(400)}
      package_id          {integer}
      parent_id           {integer references cr_items(item_id) on delete cascade}
      publish_status      {character varying(40)}
      page_template       {integer references cr_items(item_id) on delete cascade}
      assignee            {integer references parties(party_id) on delete cascade}
      state               {[::xo::dc map_datatype text]}
    }] $populate

    set hkey_in_view ""
  }

  ::xo::db::require index -table xowiki_form_instance_item_index -col item_id -unique true
  ::xo::db::require index -table xowiki_form_instance_item_index -col parent_id,name -unique true
  ::xo::db::require index -table xowiki_form_instance_item_index -col page_template
  ::xo::db::require index -table xowiki_form_instance_item_index -col page_template,package_id
  ::xo::db::require index -table xowiki_form_instance_item_index -col parent_id
  ::xo::db::require index -table xowiki_form_instance_item_index -col parent_id,page_template
  ::xo::db::require index -table xowiki_form_instance_item_index -col assignee

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
  if {[db_type] eq "postgresql"} {
    # More performant version using lateral. Oracle could support this
    # as well since version 12c.
    set sql [subst {
      SELECT
         xi.package_id, xi.parent_id, xi.name,
         $hkey_in_view xi.publish_status, xi.assignee, xi.state, xi.page_template, xi.item_id,
         o.object_id, o.object_type, o.title AS object_title,
         io.context_id,
         io.creation_date,
         io.creation_user,
         io.creation_ip,
         ci.storage_type,
         o.security_inherit_p,
         o.last_modified, o.modifying_user, o.modifying_ip,
         cr.revision_id, cr.title, content_revision__get_content(ci.live_revision) AS text,
         cr.description, cr.publish_date, cr.mime_type, cr.nls_language,
         (select xowiki_form_page_id from xowiki_form_page
          where xowiki_form_page_id = ci.live_revision) as xowiki_form_page_id,
         xowiki_page_instance.page_instance_id,
         xowiki_page_instance.instance_attributes,
         xowiki_page.page_id,
         xowiki_page.page_order,
         xowiki_page.creator
      FROM xowiki_form_instance_item_index xi
         inner join acs_objects io on object_id = xi.item_id,
         lateral (select live_revision, storage_type from cr_items where item_id = xi.item_id) ci
         left join cr_revisions cr on (cr.revision_id = ci.live_revision)
         left join acs_objects o on (o.object_id = ci.live_revision)
         left join xowiki_page on (xowiki_page.page_id = ci.live_revision)
         left join xowiki_page_instance on (xowiki_page_instance.page_instance_id = ci.live_revision)
    }]
  } else {
    set sql [subst {
      SELECT
         xi.package_id, xi.parent_id, xi.name,
         xi.publish_status, xi.assignee, xi.state, xi.page_template, xi.item_id,
         o.object_id, o.object_type, o.title AS object_title,
         io.context_id,
         io.creation_date,
         io.creation_user,
         io.creation_ip,
         ci.storage_type,
         o.security_inherit_p,
         o.last_modified, o.modifying_user, o.modifying_ip,
         cr.revision_id, cr.title,
         cr.content as data,
         cr_text.text,
         cr.description, cr.publish_date, cr.mime_type, cr.nls_language,
         (select xowiki_form_page_id from xowiki_form_page
          where xowiki_form_page_id = ci.live_revision) as xowiki_form_page_id,
         xowiki_page_instance.page_instance_id,
         xowiki_page_instance.instance_attributes,
         xowiki_page.page_id,
         xowiki_page.page_order,
         xowiki_page.creator
      FROM cr_text, xowiki_form_instance_item_index xi
         inner join acs_objects io on object_id = xi.item_id
         left join cr_items ci on (ci.item_id = xi.item_id)
         left join cr_revisions cr on (cr.revision_id = ci.live_revision)
         left join acs_objects o on (o.object_id = ci.live_revision)
         left join xowiki_page on (o.object_id = xowiki_page.page_id)
         left join xowiki_page_instance on (o.object_id = xowiki_page_instance.page_instance_id)
    }]
  }
  ::xo::db::require view xowiki_form_instance_item_view $sql

  # xowiki_form_instance_children:
  #
  #   Return the root_item_id and all attributes of the
  #   form_instance_item_index of all child items under the tree based
  #   on parent_ids. Use a query like the following to count the
  #   children of an item having a certain page_template (e.g.
  #   find all the folders/links/... having the specified item
  #   as parent):
  #
  #      select count(*) from xowiki_form_instance_children
  #      where root_item_id = 18255779
  #         and page_template = 20260757
  #         and publish_status='ready';
  #

  if {[db_type] eq "postgresql"} {

    ::xo::db::require view xowiki_form_instance_children {
      WITH RECURSIVE child_items AS (
        select item_id as root_item_id, * from xowiki_form_instance_item_index
      UNION ALL
        select child_items.root_item_id, xi.* from xowiki_form_instance_item_index xi, child_items
        where xi.parent_id = child_items.item_id
      )
      select * from child_items
    }

  } else {
    #
    # Oracle
    #
    ::xo::db::require view xowiki_form_instance_children {
      WITH child_items (
          root_item_id, item_id, name, package_id, parent_id, publish_status, page_template, assignee, state
      ) AS (
        select item_id as root_item_id,
               xi.item_id, xi.name, xi.package_id, xi.parent_id, xi.publish_status, xi.page_template, xi.assignee, xi.state
        from xowiki_form_instance_item_index xi
      UNION ALL
        select child_items.root_item_id,
               xi.item_id, xi.name, xi.package_id, xi.parent_id, xi.publish_status, xi.page_template, xi.assignee, xi.state
        from xowiki_form_instance_item_index xi, child_items
        where xi.parent_id = child_items.item_id
      )
      select * from child_items
    }
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
  if {[db_type] eq "postgresql"} {

    ::xo::db::require view xowiki_form_instance_attributes {
      SELECT
         ci.item_id,
         o.package_id,
         o.object_id, o.object_type, o.title AS object_title, o.context_id,
         o.security_inherit_p, o.creation_user, o.creation_date, o.creation_ip,
         o.last_modified, o.modifying_user, o.modifying_ip,
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
  } else {
    #
    # Oracle
    #
    ::xo::db::require view xowiki_form_instance_attributes {
      SELECT
         ci.item_id,
         o.package_id,
         o.object_id, o.object_type, o.title AS object_title, o.context_id,
         o.security_inherit_p, o.creation_user, o.creation_date, o.creation_ip,
         o.last_modified, o.modifying_user, o.modifying_ip,
         cr.revision_id, cr.title, cr.content as data,
         cr_text.text, cr.description, cr.publish_date, cr.mime_type, cr.nls_language,
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
  # number of sequences (in PostgreSQL or Oracle), the database
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
      set generated_name [:generate -parent_id $parent_id -name $name]
      if {[::xo::db::CrClass lookup -name $generated_name -parent_id $parent_id] eq "0"} {
        return $generated_name
      }
    }
  }

  #############################
  #
  # Create the xowiki_cache
  #
  # We do here the same way as in xotcl-core/tcl/05-db-procs.tcl
  #
  # The sizes can be tailored in the config
  # file like the following:
  #
  # ns_section ns/server/${server}/acs/xowiki
  #   ns_param CacheSize                1000000
  #   ns_param CachePartitions                3
  #
  if {[catch {ns_cache flush xowiki_cache-0 NOTHING}]} {
    ns_log notice "xotcl-core: creating xowiki cache"

    ::acs::KeyPartitionedCache create ::xowiki::cache \
        -name xowiki_cache \
        -package_key xowiki \
        -parameter Cache \
        -default_size 600000 \
        -partitions 2
  }

  #############################
  #
  # Page definitions
  #

  Page set recursion_count 0
  Page array set RE {
    include {{{([^<]+?)}}([^\}\\]|$)}
    anchor  {\\\[\\\[([^\]]+?)\\\]\\\]}
    div     {&gt;&gt;([^&<]*?)&lt;&lt;([ \n]*)?}
    clean   {[\\](\{\{|&gt;&gt;|\[\[)}
    clean2  { <br */?> *(<div)}
  }
  Page set markupmap(escape)   [list "\\\[\[" \03\01 "\\\{\{" \03\02  "\\&gt;&gt;" \03\03]
  Page set markupmap(unescape) [list \03\01 "\[\["    \03\02 "\{\{"   \03\03 "&gt;&gt;"  ]

  #
  # Templating and CSS
  #

  Page proc quoted_html_content text {
    list [ad_text_to_html -- $text] text/html
  }

  #
  # Operations on the whole instance
  #

  #
  # Page marshall/demarshall operations
  #
  # serialize_relocatable is a helper method of marshall that returns
  # relocatable objects (objects without leading colons). The
  # serialized objects will be recreated in the current namespace at
  # the target.
  #
  Page instproc serialize_relocatable {} {
    if {[::package vcompare [package require xotcl::serializer] 2.1] > -1} {
      #
      # nsf 2.1 has support for specifying the target as argument of
      # the serialize method.
      #
      set content [:serialize -target [string trimleft [self] :]]
    } else {
      #
      # Since we serialize nx and XOTcl objects, make objects the
      # old-fashioned way relocatable. This is dangerous, since it
      # might substitute as well content.
      #
      set content [:serialize]
      #
      # The following statement drops the leading colons from the object
      # names such that the imported objects are inserted into the
      # current (rather than the global) namespace. Rather than the
      # global namespace. The approach is cruel, but backward compatible
      # and avoids potential name clashes with pre-existing objects.
      #
      # Replace the first occurrence of the object name (in the alloc/create
      # statement):
      #
      regsub { ::([0-9]+) } $content { \1 } content

      #
      # Replace leading occurrences of the object name (when e.g. procs
      # are as well exported as separate statements)
      #
      regsub -all -- {\n::([0-9]+) } $content "\n\\1 " content
    }
    return $content
  }

  #
  # Page marshall
  #
  # -mode might be "export" or "copy" (latter used via clipboard)
  #
  Page instproc marshall {{-mode export}} {
    :unset_temporary_instance_variables

    set old_creation_user  [:creation_user]
    set old_modifying_user ${:modifying_user}
    set :creation_user   [:map_party -property creation_user $old_creation_user]
    set :modifying_user  [:map_party -property modifying_user $old_modifying_user]
    if {$mode eq "export" && [:is_new_entry ${:name}]} {
      #
      # For anonymous entries, names might clash in the target
      # instance. If we create on the target site for anonymous
      # entries always new instances, we end up with duplicates.
      # Therefore, we rename anonymous entries during export to
      #    ip_address:port/item_id
      #
      set server [ns_info server]
      set port [ns_config ns/server/${server}/module/nssock port]
      set new_name [ns_info address]:${port}-${:item_id}
    }

    if {[info exists new_name]} {
      #
      # We have a new name, so patch this locally to get it into the
      # serialized content.
      #
      set old_name ${:name}
      set :name $new_name
      set content [:serialize_relocatable]
      set :name $old_name
    } else {
      set content [:serialize_relocatable]
    }
    set :creation_user  $old_creation_user
    set :modifying_user $old_modifying_user

    return $content
  }

  File instproc marshall {{-mode export}} {
    set fn [:full_file_name]
    if {$mode eq "export"} {
      set :__file_content [::base64::encode [::xo::read_file $fn]]
    } else {
      set :__file_name $fn
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
    set tree_ids [::xowiki::Category get_mapped_trees -object_id ${:package_id} \
                      -names [list $tree_name] -output tree_id]
    # Make sure to have only one tree_id, in case multiple trees are
    # mapped with the same name.
    set tree_id [lindex $tree_ids 0]
    set tree_description [dict get [category_tree::get_data $tree_id] description]
    set categories [list]
    if {![info exists :__category_map]} {
      set :__category_map [dict create]
    }
    foreach category [::xowiki::Category get_category_infos -tree_id $tree_id] {
      lassign $category category_id category_name deprecated_p level
      lappend categories $level $category_name
      set names($level) $category_name
      set node_name $tree_name
      for {set l 1} {$l <= $level} {incr l} {append node_name /$names($l)}
      dict set :__category_map $category_id $node_name
    }
    set cmd [list :category_import \
                 -name $tree_name -description $tree_description \
                 -locale [lang::system::site_wide_locale] \
                 -categories $categories]
    if {![info exists :__map_command] || [string first $cmd ${:__map_command}] == -1} {
      append :__map_command \n $cmd
    }
    return ${:__category_map}
    #:log "cmd=$cmd"
  }

  Page instproc build_instance_attribute_map {form_fields} {
    #
    # Build the data structure for mapping internal values (IDs) into
    # string representations and vice versa. In particular, it builds
    # and maintains the __instance_attribute_map, which is an
    # associative list (attribute/value pairs) for form-field attributes.
    #
    #foreach f $form_fields {lappend fns [list [$f name] [$f info class]]}
    #:msg "page ${:name} build_instance_attribute_map $fns"
    if {![info exists :__instance_attribute_map]} {
      set :__instance_attribute_map [dict create]
    }
    foreach f $form_fields {
      set multiple [expr {[$f exists multiple] ? [$f set multiple] : 0}]
      #:msg "$f [$f name] cat_tree [$f exists category_tree] is fc: [$f exists is_category_field]"
      if {[$f exists category_tree] && [$f exists is_category_field]} {
        #:msg "page ${:name} field [$f name] is a category_id from [$f category_tree]"
        dict set :__instance_attribute_map [$f name] [list category [$f category_tree] $multiple]
        :category_export [$f category_tree]
      } elseif {[$f exists is_party_id]} {
        #:msg "page ${:name} field [$f name] is a party_id"
        dict set :__instance_attribute_map [$f name] [list party_id $multiple]
      } elseif {[$f istype "::xowiki::formfield::file"]} {
        dict set :__instance_attribute_map [$f name] [list file 0]
      }
    }
    return ${:__instance_attribute_map}
  }

  Page instproc category_import {-name -description -locale -categories} {
    # Execute the category import for every tree name only once per request
    set key ::__xowiki_category_import($name)
    if {[info exists $key]} return

    # ok, it is the first request
    #:msg "... catetegoy_import [self args]"

    # Do we have a tree with the specified named mapped?
    set tree_ids [::xowiki::Category get_mapped_trees -object_id ${:package_id} -locale $locale \
                      -names [list $name] -output tree_id]
    set tree_id [lindex $tree_ids 0]; # handle multiple mapped trees with same name
    if {$tree_id eq ""} {
      # The tree is not mapped, we import the category tree
      :log "...importing category tree $name"
      set tree_id [category_tree::import -name $name -description $description \
                       -locale $locale -categories $categories]
      category_tree::map -tree_id $tree_id -object_id ${:package_id}
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
    #:msg "... catetegoy_import reverse map [array names ::__xowiki_reverse_category_map]"
    # mark the tree with this name as already imported
    set $key 1
  }


  Form instproc marshall {{-mode export}} {
    #set form_fields [:create_form_fields_from_form_constraints [:get_form_constraints]]
    #:log "--ff=$form_fields"
    # :build_instance_attribute_map $form_fields
    next
  }

  FormPage instproc map_values {map_type values} {
    # Map a list of values (for multi-valued form fields)
    # :log "map_values $map_type, $values"
    set mapped_values [list]
    foreach value $values {lappend mapped_values [:map_value $map_type $value]}
    return $mapped_values
  }

  FormPage instproc map_value {map_type value} {
    :log "map_value $map_type, $value"
    if {$map_type eq "category" && $value ne ""} {
      #
      # map a category item
      #
      return [dict get ${:__category_map} $value]
    } elseif {$map_type eq "party_id" && $value ne ""} {
      #
      # map a party_id
      #
      return [:map_party -property $map_type $value]
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
    # Note that only types of form-fields implied by the derived form
    # constraints are recognized. E.g. In workflows, it might be
    # necessary to move e.g. category definitions into the global form
    # constraints.
    #
    if {$mode eq "copy" && ![string match "*revision_id*" ${:instance_attributes}]} {
      return [next]
    }
    set form_fields [:create_form_fields_from_form_constraints \
                         [:get_form_constraints]]
    :build_instance_attribute_map $form_fields

    # In case we have a mapping from IDs to external values, use it
    # and rewrite instance attributes. Note that the marshalled
    # objects have to be flushed from memory later since the
    # representation of instances_attributes is changed by this
    # method.
    #
    if {[info exists :__instance_attribute_map]} {
      # :log "+++ we have an instance_attribute_map for ${:name}"
      # :log "+++ starting with instance_attributes [:instance_attributes]"
      array set multiple_index [list category 2 party_id 1 file 1]
      set ia [list]
      foreach {name value} [:instance_attributes] {
        #:log "marshall check $name $value [info exists use($name)]"
        if {[dict exists ${:__instance_attribute_map} $name]} {
          set use_name [dict get ${:__instance_attribute_map} $name]
          set map_type [lindex $use_name 0]
          set multiple [lindex $use_name $multiple_index($map_type)]
          #:log "+++ marshall check $name $value use <$use($name)> m=?$multiple"
          if {$multiple} {
            lappend ia $name [:map_values $map_type $value]
          } else {
            lappend ia $name [:map_value $map_type $value]
          }
        } else {
          # nothing to map
          lappend ia $name $value
        }
      }
      set :instance_attributes $ia
      #:log "+++ setting instance_attributes $ia"
    }
    set old_assignee [:assignee]
    set :assignee  [:map_party -property assignee $old_assignee]
    set r [next]
    set :assignee  $old_assignee
    return $r
  }

  Page instproc map_party {-property party_id} {
    if {$party_id eq "" || $party_id == 0} {
      return $party_id
    }
    ad_try {
      acs_user::get -user_id $party_id -array info
      set result [list]
      foreach a {username email first_names last_name screen_name url} {
        lappend result $a $info($a)
      }
      :log "--    map_party $party_id: $result"
      return $result
    } on error {errorMsg} {
      # swallow errors; there should be a better way to check if user
      # and or group info exists
    }
    ad_try {
      group::get -group_id $party_id -array info
      :log "got group info: [array get info]"
      set result [array get info]
      set members {}
      foreach member_id [group::get_members -group_id $party_id] {
        lappend members [:map_party -property $property $member_id]
      }
      lappend result members $members
      ns_log notice "--    map_party $party_id: $result"
      return $result
    } on error {errorMsg} {
      # swallow errors; there should be a better way to check if user
      # and or group info exists
    }
    ns_log warning "Cannot map party_id $party_id, probably not a user; property $property lost during export"
    return {}
  }

  Page instproc reverse_map_party {-entry -default_party {-create_user_ids 0}} {
    # So far, we just handle users, but we should support parties in
    # the future as well.http://localhost:8003/nimawf/admin/export

    set email [expr {[dict exists $entry email] ? [dict get $entry email] : ""}]
    if {$email ne ""} {
      set id [party::get_by_email -email $email]
      if {$id ne ""} { return $id }
    }
    set username [expr {[dict exists $entry username] ? [dict get $entry username] : ""}]
    if {$username ne ""} {
      set id [acs_user::get_by_username -username $username]
      if {$id ne ""} { return $id }
    }
    set group_name [expr {[dict exists $entry group_name] ? [dict get $entry group_name] : ""}]
    if {$group_name ne ""} {
      set id [group::get_id -group_name $group_name]
      if {$id ne ""} { return $id }
    }

    if {$create_user_ids} {
      if {$group_name ne ""} {
        :log "+++ create a new group group_name=${group_name}"
        set group_id [group::new -group_name $group_name]
        group::update -group_id $group_id [list join_policy [dict get $entry join_policy]]
        ns_log notice "+++ reverse_party_map: we could add members [dict get $entry members] - but we don't"
        return $group_id
      } else {
        :log "+++ create a new user username=${username}, email=${email}"
        set status [auth::create_user -username $username -email $email \
                        -first_names [dict get $entry first_names] \
                        -last_name [dict get $entry last_name] \
                        -screen_name [dict get $entry screen_name] \
                        -url [dict get $entry url] -nologin]
        set creation_status [dict get $status creation_status]
        if {$creation_status eq "ok"} {
          return [dict get $status user_id]
        }
        :log "+++ create user username=${username}, email=${email} failed, reason=${creation_status}"
      }
    }
    return $default_party
  }


  Page instproc reverse_map_party_attribute {-attribute {-default_party 0} {-create_user_ids 0}} {
    if {![info exists :$attribute]} {
      set :$attribute $default_party
    } elseif {[llength [set :$attribute]] < 2} {
      set :$attribute $default_party
    } else {
      set :$attribute [:reverse_map_party \
                           -entry [set :$attribute] \
                           -default_party $default_party \
                           -create_user_ids $create_user_ids]
    }
  }

  Page instproc demarshall {-parent_id -package_id -creation_user {-create_user_ids 0}} {
    # this method is the counterpart of marshall
    # Unset the context_id, which would otherwise come from the
    # original object and persisted. By default, will be set to the
    # new object's parent_id
    unset -nocomplain -- :context_id
    set :parent_id $parent_id
    set :package_id $package_id
    :reverse_map_party_attribute -attribute creation_user  \
        -default_party $creation_user -create_user_ids $create_user_ids
    :reverse_map_party_attribute -attribute modifying_user \
        -default_party $creation_user -create_user_ids $create_user_ids
    # If we import from an old database without page_order, provide a
    # default value
    if {![info exists :page_order]} {set :page_order ""}
    set is_folder_page [:is_folder_page]
    #:msg "is-folder-page ${:name} => $is_folder_page"
    if {$is_folder_page} {
      # reset names if necessary (e.g. import from old releases)
      set :name [:build_name]
    } else {
      # Check, if nls_language and lang are aligned.
      if {[regexp {^(..):} ${:name} _ lang]} {
        if {[string range [:nls_language] 0 1] ne $lang} {
          set old_nls_language [:nls_language]
          :nls_language [:get_nls_language_from_lang $lang]
          ns_log notice "nls_language for item ${:name} set from $old_nls_language to [:nls_language]"
        }
      }
    }
    # in the general case, no more actions required
    #:msg "demarshall ${:name} DONE"
  }

  File instproc demarshall {args} {
    next
    # we have to care about saving the file content

    if {[info exists :__file_content]} {
      ::xo::write_tmp_file :import_file [::base64::decode ${:__file_content}]
      unset :__file_content

    } elseif {[info exists :__file_name]} {
      set :import_file ${:__file_name}
      unset :__file_name

    } else {
      error "either __file_content or __file_name must be set"
    }
  }

  # set default values.
  # todo: with slots, it should be easier to set default values
  # for non-existing variables
  PageInstance instproc demarshall {args} {
    # some older versions do not have anon_instances and no slots
    if {![info exists :anon_instances]} {
      set :anon_instances "f"
    }
    next
  }
  Form instproc demarshall {args} {
    # Some older versions do not have anon_instances and no slots
    if {![info exists :anon_instances]} {
      set :anon_instances "t"
    }
    next
  }


  FormPage instproc reverse_map_values {-creation_user -create_user_ids map_type values category_ids_name} {
    # Apply reverse_map_value to a list of values (for multi-valued
    # form fields)
    :upvar $category_ids_name category_ids
    set mapped_values [list]
    foreach value $values {
      lappend mapped_values [:reverse_map_value \
                                 -creation_user $creation_user -create_user_ids $create_user_ids \
                                 $map_type $value category_ids]
    }
    return $mapped_values
  }

  FormPage instproc reverse_map_value {-creation_user -create_user_ids map_type value category_ids_name} {
    # Perform the inverse function of map_value. During export, internal
    # representations are exchanged by string representations, which are
    # mapped here again to internal representations
    :upvar $category_ids_name category_ids
    if {[info exists ::__xowiki_reverse_category_map($value)]} {
      #:msg "map value '$value' (category tree: $use($name)) of ${:name} to an ID"
      lappend category_ids $::__xowiki_reverse_category_map($value)
      return $::__xowiki_reverse_category_map($value)
    } elseif {$map_type eq "party_id"} {
      return [:reverse_map_party \
                  -entry $value \
                  -default_party $creation_user \
                  -create_user_ids $create_user_ids]
    } elseif {$value eq ""} {
      return ""
    } else {
      :msg "cannot map value '$value' (map_type $map_type)\
        of ${:name} to an ID; maybe there is some\
        same_named category tree with fewer entries..."
      :msg "reverse category map has values [lsort [array names ::__xowiki_reverse_category_map]]"
      return ""
    }
  }

  FormPage instproc demarshall {-parent_id -package_id -creation_user {-create_user_ids 0}} {
    # reverse map assignees
    :reverse_map_party_attribute -attribute assignee -create_user_ids $create_user_ids
    #
    # The function will compute the category_ids, which are were used
    # to categorize these objects in the source instance.
    set category_ids [list]

    #:msg "${:name} check cm=[info exists ::__xowiki_reverse_category_map] && iam=[info exists :__instance_attribute_map]"

    if {[info exists ::__xowiki_reverse_category_map]
        && [info exists :__instance_attribute_map]
      } {
      #:msg "we have a instance_attribute_map"

      #
      # replace all symbolic category values by the mapped IDs
      #
      set ia [list]
      array set use ${:__instance_attribute_map}
      array set multiple_index [list category 2 party_id 1 file 1]
      foreach {name value} [:instance_attributes] {
        #:msg "use($name) --> [info exists use($name)]"
        if {[info exists use($name)]} {
          #:msg "try to map value '$value' (category tree: $use($name))"
          set map_type [lindex $use($name) 0]
          set multiple [lindex $use($name) $multiple_index($map_type)]
          if {$multiple eq ""} {set multiple 1}
          if {$multiple} {
            lappend ia $name [:reverse_map_values \
                                  -creation_user $creation_user -create_user_ids $create_user_ids \
                                  $map_type $value category_ids]
          } else {
            lappend ia $name [:reverse_map_value \
                                  -creation_user $creation_user -create_user_ids $create_user_ids \
                                  $map_type $value category_ids]
          }
        } else {
          # nothing to map
          lappend ia $name $value
        }
      }
      set :instance_attributes $ia
      #:msg  "${:name} saving instance_attributes $ia"
    }
    set r [next]
    set :__category_ids [lsort -unique $category_ids]
    return $r
  }

  ############################################
  #
  # conditions for policy rules
  #
  ############################################
  Page instproc condition=match {query_context value} {
    #
    # Condition for conditional checks in policy rules
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
    #:msg "query_context='$query_context', value='$value'"
    if {[llength $value] != 2} {
      error "two arguments for match required, [llength $value] passed (arguments='$value')"
    }
    ad_try {
      set success [string match [lindex $value 1] [set :[lindex $value 0]]]
    } on error {errorMsg} {
      ns_log error "error during condition match: $errorMsg"
      set success 0
    }
    return $success
  }

  Page instproc condition=regexp {query_context value} {
    #
    # Condition for conditional checks in policy rules
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
    #:msg "query_context='$query_context', value='$value'"
    if {[llength $value] != 2} {
      error "two arguments for regexp required, [llength $value] passed (arguments='$value')"
    }
    ad_try {
      set success [regexp [lindex $value 1] [set :[lindex $value 0]]]
    } on error {errorMsg} {
      ns_log error "error during condition regexp: $errorMsg"
      set success 0
    }
    return $success
  }

  Page instproc condition=is_folder_page {query_context value} {
    # query_context and value are ignored
    return [:is_folder_page]
  }


  Page instproc copy_content_vars {-from_object:required} {
    array set excluded_var {
      folder_id 1 package_id 1 absolute_links 1 lang_links 1 modifying_user 1
      publish_status 1 item_id 1 revision_id 1 last_modified 1
      parent_id 1 context_id 1
    }
    foreach var [$from_object info vars] {
      # don't copy vars starting with "__"
      if {[string match "__*" $var]} continue
      if {![info exists excluded_var($var)]} {
        set :$var [$from_object set $var]
      }
    }
  }

  Page proc import {-user_id -package_id -folder_id {-replace 0} -objects} {
    :log "DEPRECATED"
    if {![info exists package_id]}  {set package_id  [::xo::cc package_id]}
    set cmd [list ::$package_id import -replace $replace]

    if {[info exists user_id]}   {lappend cmd -user_id $user_id}
    if {[info exists objects]}   {lappend cmd -objects $objects}
    {*}$cmd
  }

  #
  # Tag management, get_tags works on instance or globally.
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

    #
    # Map funny characters in tags to white-space. Tags are just
    # single words, no quotes are allowed. The resulting tags must be
    # compatible with "Package->validate_tag".
    #
    regsub -all {[^\w.-]+} $tags " " tags

    foreach tag [split $tags " "] {
      if {$tag ne ""} {
        ::xo::dc dml insert_tag \
            "insert into xowiki_tags (item_id,package_id, user_id, tag, time) \
          values (:item_id, :package_id, :user_id, :tag, CURRENT_TIMESTAMP)"
      }
    }
    search::queue -object_id $revision_id -event UPDATE
  }

  Page proc get_tags {-package_id:required -item_id -user_id} {
    if {[info exists item_id]} {
      if {[info exists user_id]} {
        # tags for item and user
        set tags [::xo::dc list -prepare integer,integer,integer get_tags {
          SELECT distinct tag from xowiki_tags
          where user_id = :user_id and item_id = :item_id and package_id = :package_id
        }]
      } else {
        #
        # All tags for this item
        #
        set tags [::xo::dc list -prepare integer,integer get_tags {
          SELECT distinct tag from xowiki_tags
          where item_id = :item_id and package_id = :package_id
        }]
      }
    } else {
      if {[info exists user_id]} {
        #
        # All tags for this user
        #
        set tags [::xo::dc list -prepare integer,integer get_tags {
          SELECT distinct tag from xowiki_tags
          where user_id = :user_id and package_id :package_id
        }]
      } else {
        #
        # All tags for the package instance
        #
        set tags [::xo::dc list -prepare integer get_tags {
          SELECT distinct tag from xowiki_tags
          where package_id = :package_id
        }]
      }
    }
    return $tags
  }


  #
  # Methods of ::xowiki::Page
  #

  Page instforward query_parameter {%set :package_id} %proc
  Page instforward exists_query_parameter {%set :package_id} %proc
  Page instforward form_parameter {%set :package_id} %proc
  Page instforward exists_form_parameter {%set :package_id} %proc

  Page instproc get_query_parameter_return_url {{default ""}} {
    #
    # Get the return_url from query parameters and check, if this is
    # local.
    #
    set return_url [:query_parameter return_url:localurl $default]
    #if {[util::external_url_p $return_url]} {
    #  ns_log warning "return_url $return_url is apparently an external URL"
    #  ad_return_complaint 1 "Page <b>'${:name}'</b> non-local return_url was specified"
    #  ad_script_abort
    #}
    return $return_url
  }


  #   Page instproc init {} {
  #     :log "--W "
  #     ::xo::show_stack
  #     next
  #   }

  #   Page instproc destroy  {} {
  #     :log "--W "
  #     ::xo::show_stack
  #     next
  #   }

  #
  # check certain properties of a page (is_* methods)
  #

  Page ad_instproc is_folder_page {
    {-include_folder_links true}
  } {

    Check, if page is a folder.  This function is typically overlaaded
    by specializations. Plain xowiki::Pages are never folders.

    @param include_folder_links return true, if the current page is a
           link to a folder.

    @return boolean
  } {
    return 0
  }

  FormPage ad_instproc is_folder_page {
    {-include_folder_links true}
  } {
    Check, if FormPage is a folder. A FormPage is a folder when its
    page template is the folder.form or if this is a link pointing to
    a folder.

    @param include_folder_links return true, if the current page is a
           link to a folder.
    @return boolean
  } {
    #
    # Make sure, the page_template is instantiated
    #
    if {![nsf::is object ::${:page_template}]} {
      ::xo::db::CrClass get_instance_from_db -item_id ${:page_template}
    }
    set page_template_name [${:page_template} name]
    if {$page_template_name eq "en:folder.form"} {
      return 1
    } elseif {$include_folder_links && $page_template_name eq "en:link.form"} {
      set link_type [:get_property_from_link_page link_type]
      return [expr {$link_type eq "folder_link"}]
    } else {
      return 0
    }
  }

  #
  # Check, if a page is a link
  #
  Page instproc is_link_page {} {
    return 0
  }

  FormPage instproc is_link_page {} {
    #
    # Make sure, the page_template is instantiated
    #
    if {![nsf::is object ::${:page_template}]} {
      ::xo::db::CrClass get_instance_from_db -item_id ${:page_template}
    }
    return [expr {[${:page_template} name] eq "en:link.form"}]
  }

  Page instproc is_unprefixed {} {
    #
    # Pages which should not get an extra language prefix.  In case,
    # your package has further such requirements, extend this proc in
    # you package.
    #
    return [expr {[:is_folder_page]
                  || [:is_link_page]
                  || ${:name} eq ${:revision_id}
                }]
  }

  #
  # link properties
  #
  Page instproc get_property_from_link_page {property {default ""}} {

    if {![:is_link_page]} {
      return $default
    }

    set item_ref [:property link]
    ::xo::db::CrClass get_instance_from_db -item_id ${:item_id}
    set props [::xo::cc cache [list ::${:item_id} compute_link_properties $item_ref]]

    if {[dict exists $props $property]} {
      #${:item_id} msg "prop $property ==> [dict get $props $property]"
      return [dict get $props $property]
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
    set item_id [:get_property_from_link_page item_id 0]
    if {$item_id == 0} {return ""}
    set target [::xo::db::CrClass get_instance_from_db -item_id $item_id]
    set target_package_id [$target package_id]
    if {$target_package_id != ${:package_id}} {
      ::xowiki::Package require $target_package_id
      #::xowiki::Package initialize -package_id $target_package_id -init_url false -keep_cc true
    }
    if {$depth > 1 && [$target is_link_page]} {
      set target [:get_target_from_link_page -count [expr {$depth - 1}]]
    }
    return $target
  }

  FormPage instproc compute_link_properties {item_ref} {
    set package_id ${:package_id}
    set page [::$package_id get_page_from_item_ref \
                  -default_lang [:lang] \
                  -parent_id ${:parent_id} \
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
    #:msg [list item_ref $item_ref item_id $item_id link_type $link_type cross_package $cross_package]
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
    return [:exists_property form_constraints]
  }

  FormPage instproc hstore_attributes {} {
    # Per default, we save all instance attributes in hstore, but a
    # subclass/object might have different requirements.
    return ${:instance_attributes}
  }

  #
  # Update helper for xowiki_form_instance_item_index (called from
  # cr_procs, whenever a live-revision becomes updated).
  #
  FormPage ad_instproc update_item_index {} {

    Tailored version of CrItem.update_item_index to keep
    insert_xowiki_form_instance_item_index in sync after updates.

  } {
    :instvar name item_id package_id parent_id publish_status \
        page_template instance_attributes assignee state

    set useHstore [::$package_id get_parameter use_hstore 0]
    set updateVars {name = :name, package_id = :package_id,
      parent_id = :parent_id, publish_status = :publish_status,
      page_template = :page_template, assignee = :assignee,
      state = :state}

    if {$useHstore} {
      set hkey [::xowiki::hstore::dict_as_hkey [:hstore_attributes]]
      append updateVars ", hkey = '$hkey'"
    }

    set rows [xo::dc dml update_xowiki_form_instance_item_index [subst {
      update xowiki_form_instance_item_index
      set $updateVars
      where item_id = :item_id
    }]]

    if {$rows ne "" && $rows < 1} {
      set insertVars {item_id, name, package_id, parent_id, publish_status,
        page_template, assignee, state
      }
      set insertValues {:item_id, :name, :package_id, :parent_id, :publish_status,
        :page_template, :assignee, :state
      }
      if {$useHstore} {
        append insertVars {, hkey}
        append insertValues ", '$hkey'"
      }

      ::xo::dc dml insert_xowiki_form_instance_item_index [subst {
        insert into xowiki_form_instance_item_index
        ($insertVars) values ($insertValues)
      }]
    }
  }

  FormPage ad_instproc update_attribute_from_slot {-revision_id slot value} {

    Tailored version of update_attribute_from_slot to keep
    insert_xowiki_form_instance_item_index in sync after single
    attribute updates.

  } {
    #
    # Perform first the regular operations.
    #
    next
    #
    # Make sure to update update_item_index when the attribute is
    # contained in the xowiki_form_instance_item_index.
    #
    set colName [$slot column_name]

    if {$colName in {
      package_id
      parent_id
      publish_status
      page_template
      assignee
      state
    }} {
      ::xowiki::update_item_index -item_id ${:item_id} -$colName $value
    } elseif {
              $colName eq "instance_attributes"
              && [::xo::dc has_hstore]
              && [::${:package_id} get_parameter use_hstore 0]
            } {
      ::xowiki::update_item_index -item_id ${:item_id} -hstore_attributes $value
    }
  }

  ad_proc update_item_index {
    -item_id:required
    -package_id
    -parent_id
    -publish_status
    -page_template
    -assignee
    -state
    -hstore_attributes
  } {

    Helper function to update single or multiple fields of the
    xowiki_form_instance_item_index. Call this function only when
    updating fields of the xowiki_form_instance_item_index in cases
    where the standard API based on save and save_use can not be used.

  } {
    set updates {}
    foreach var {
      package_id parent_id
      publish_status page_template
      assignee state
    } {
      if {[info exists $var]} {
        lappend updates "$var = :$var"
      }
    }
    if {[info exists hstore_attributes]} {
      set hkey [::xowiki::hstore::dict_as_hkey $hstore_attributes]
      lappend updates "hkey = '$hkey'"
    }
    if {[llength $updates] > 0} {
      set setclause [join $updates ,]
      xo::dc dml update_xowiki_form_instance_item_index [subst {
        update xowiki_form_instance_item_index
        set $setclause
        where item_id = :item_id
      }]
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
    #ns_log notice "=== fetch_object $item_id"
    #
    # We handle here just loading object instances via item_id, since
    # only live_revisions are kept in xowiki_form_instance_item_index.
    # The loading via revision_id happens as before in CrClass.
    #
    if {$item_id == 0} {
      return [next]
    }

    if {![nsf::is object $object]} {
      # if the object does not yet exist, we have to create it
      :create $object
    }

    db_with_handle db {
      set sql [::xo::dc prepare -handle $db -argtypes integer {
        select * from xowiki_form_instance_item_view where item_id = :item_id
      }]
      set selection [db_exec 0or1row $db dbqd..Formpage-fetch_object $sql]
    }

    if {$selection eq ""} {
      error [subst {
        The form page with item_id $item_id was not found in the
        xowiki_form_instance_item_index.  Consider 'DROP TABLE
        xowiki_form_instance_item_index CASCADE;' and restart server
        (the table is rebuilt automatically, but this could take a
        while, when the number of pages is huge).
      }]
    }

    $object mset [ns_set array $selection]

    if {$initialize} {
      $object initialize_loaded_object
    }
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

    # Fetch fresh instance from db so that we have actual values
    # from the live revision for the update of the item_index.

    set page [::xo::db::CrClass get_instance_from_db -revision_id $revision_id]
    $page publish_status $publish_status
    $page update_item_index
  }

  #
  # helper for nls and lang
  #

  Page instproc lang {} {
    return [string range ${:nls_language} 0 1]
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
    set name ${:name}
    set stripped_name $name
    regexp {^..:(.*)$} $name _ stripped_name

    #:log "$name / '$stripped_name'"
    # prepend the language prefix only, if the entry is not empty
    if {$stripped_name ne ""} {
      if {[:is_folder_page] || [:is_link_page]} {
        #
        # Do not add a language prefix to folder pages
        #
        set name $stripped_name
      } else {
        if {$nls_language ne ""} {
          set :nls_language $nls_language
        }
        set name [:lang]:$stripped_name
      }
    }
    return $name
  }

  #
  # Resolve context handling.
  #
  Page instproc set_resolve_context {-package_id:required -parent_id:required -item_id} {
    #
    # Push the last values to the stack
    #
    set stack_entry [list -package_id ${:package_id} -parent_id ${:parent_id} -item_id ${:item_id}]
    lappend :resolve_context_stack $stack_entry

    #
    # Reset the current values with the specified ones
    #
    if {${:parent_id} != $parent_id} {
      if {![info exists :physical_parent_id]} {
        set :physical_parent_id ${:parent_id}
      }
      set :parent_id $parent_id
    }
    if {${:package_id} != $package_id} {
      if {![info exists :physical_package_id]} {
        set :physical_package_id ${:package_id}
      }
      set :package_id $package_id
      #:msg "doing extra require on ${:physical_package_id}"
      #::xowiki::Package require ${:physical_package_id}
    }
    if {[info exists item_id] && ${:item_id} != $item_id} {
      if {![info exists :physical_item_id]} {
        set :physical_item_id ${:item_id}
      }
      set :item_id $item_id
    }
  }

  Page instproc reset_resolve_context {} {
    #
    # Pop the last values from the stack
    #
    if {![info exists :resolve_context_stack] || [llength ${:resolve_context_stack}] < 1} {
      error "set_resolve_context and reset_resolve_context calls not balanced"
    }
    set entry [lindex ${:resolve_context_stack} end]
    set :resolve_context_stack [lrange ${:resolve_context_stack} 0 end-1]
    :configure {*}$entry
    #
    # When the stack is empty, remove the stack and the "physical*" attributes
    #
    if {[llength ${:resolve_context_stack}] == 0} {
      unset :resolve_context_stack
      foreach att {item package parent} {
        set name physical_${att}_id
        if {[info exists :$name]} {
          unset :$name
        }
      }
    }
  }

  Page instproc physical_parent_id {} {
    if {[info exists :physical_parent_id]} {
      return ${:physical_parent_id}
    } else {
      return ${:parent_id}
    }
  }

  Page instproc physical_package_id {} {
    if {[info exists :physical_package_id]} {
      return ${:physical_package_id}
    } else {
      return ${:package_id}
    }
  }
  Page instproc physical_item_id {} {
    if {[info exists :physical_item_id]} {
      return ${:physical_item_id}
    } else {
      return ${:item_id}
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
        #       # different en:folder.form
        #       break
        #     } elseif {$page_template_name eq "en:link.form"} {
        #       set fp [:is_folder_page]
        #       :msg fp=$fp
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
    # look like the following.
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

  Page instproc stats_record_count {name} {
    # This is a stub which can / should be overloaded in applications,
    # collecting statistics about certain usage pattern (e.g. exam
    # workflows).  This method is overloaded in xowf, and is here just
    # for safety reasons to avoid hard errors.
    ns_log error "the method Page->stats_record_count should not be called"
  }

  Page instproc stats_record_detail args {
    # This is a stub which can / should be overloaded in applications,
    # collecting statistics about certain usage pattern (e.g. exam
    # workflows).  This method is overloaded in xowf, and is here just
    # for safety reasons to avoid hard errors.
    ns_log error "the method Page->stats_record_detail should not be called"
  }

  Page instproc can_save {} {
    #
    # Determine the parent object of the page to be saved. If the
    # parent object is a page as well, then call can_contain. The
    # function is just determining a Boolean value such it can be used
    # for testing insertability as well.
    #
    set parent [:get_parent_object]
    if {$parent ne "" && [$parent istype ::xowiki::Page]} {
      return [$parent can_contain [self]]
    }
    return 1
  }

  Page instproc evaluate_form_field_condition {cond} {
    #
    # Can be refined
    #
    return 0
  }

  Page instproc save args {
    if {![:can_save]} {error "can't save this page under this parent"}
    ${:package_id} flush_page_fragment_cache
    set id [next]
    :check_unresolved_references
    return $id
  }

  Page instproc save_new args {
    if {![:can_save]} {error "can't save this page under this parent"}
    ${:package_id} flush_page_fragment_cache
    set id [next]
    :check_unresolved_references
    return $id
  }

  Page instproc initialize_loaded_object {} {
    if {[info exists :title] && ${:title} eq ""} {set :title ${:name}}
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
    set parent_id ${:parent_id}
    if {$parent_id > 0} {
      if {! [nsf::is object ::$parent_id] } {
        ::xo::db::CrClass get_instance_from_db -item_id $parent_id
      }
      return ::$parent_id
    }
    return ""
  }

  Page instproc get_instance_attributes {} {
    if {[info exists :instance_attributes]} {
      return ${:instance_attributes}
    }
    return ""
  }

  Page instproc update_publish_status {new_publish_status} {
    #
    # The publish_status of xowiki is used for "advertising"
    # pages. When the publish_status is e.g. in "production" or
    # "expired", users can access this object when they know obout its
    # existence (e.g. workflow assignments), but it is excluded from
    # listings, which contain - per default - only elements in
    # publish_status "ready".
    #
    # This proc can be used to change the publish status of a page and
    # handle visibility via syndication.
    #
    if {$new_publish_status ni {production ready live expired}} {
      error "update_publish_status receives invalid publish status '$new_publish_status'"
    }

    if {$new_publish_status ne ${:publish_status}} {
      :set_live_revision \
          -revision_id ${:revision_id} \
          -publish_status $new_publish_status

      ::xo::xotcl_object_cache flush ${:revision_id}
      ::xo::xotcl_object_cache flush ${:item_id}

      if {$new_publish_status eq "ready"} {
        ::xowiki::notification::do_notifications -revision_id ${:revision_id}
        ::xowiki::datasource -nocleanup ${:revision_id}
      } else {
        set revision_id ${:revision_id}
        db_dml flush_syndication {delete from syndication where object_id = :revision_id}
      }
    }
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
    uplevel [list subst [regsub -all -- $re [string map $map $string] "\[$cmd\]"]]
  }

  Page instproc error_during_render {msg} {
    return "<div class='errorMsg'>$msg</div>"
  }

  Page instproc error_in_includelet {arg msg} {
    return [:error_during_render "[_ xowiki.error_in_includelet [list arg $arg name ${:name}]]<br >\n$msg"]
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
      set page [::${:package_id} resolve_page_name_and_init_context -lang [:lang] $page_name]
      if {$page eq ""} {
        error "Cannot find page '$page_name' to be included in page '${:name}'"
      }
    } else {
      set page [self]
    }
    return $page
  }

  Page instproc instantiate_includelet {arg} {
    # we want to use package_id as proc-local variable, since the
    # cross package reference might alter it locally
    set package_id ${:package_id}

    # do we have a wellformed list?
    ::try {
      set page_name [lindex $arg 0]
    } on error {errMsg} {
      # there must be something syntactically wrong
      return [:error_in_includelet $arg [_ xowiki.error-includelet-dash_syntax_invalid]]
    }
    #:msg "includelet: [lindex $arg 0], caller parms ? '[lrange $arg 1 end]'"

    # the include is either a includelet class, or a wiki page
    if {[:isclass ::xowiki::includelet::$page_name]} {
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
      #set page [:resolve_included_page_name $page_name]
      set page [::$package_id get_page_from_item_ref \
                    -use_package_path true \
                    -use_site_wide_pages true \
                    -use_prototype_pages true \
                    -default_lang [:lang] \
                    -parent_id ${:parent_id} $page_name]

      if {$page ne "" && ![$page exists __decoration]} {
        #
        # we use as default decoration for included pages
        # the "portlet" decoration
        #
        $page set __decoration [::$package_id get_parameter default-portlet-decoration portlet]
      }
    }

    if {$page ne ""} {
      $page set __caller_parameters [lrange $arg 1 end]
      $page destroy_on_cleanup
      set :__last_includelet $page
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

    set includeletClass [$includelet info class]
    if {[$includeletClass exists cacheable] && [$includeletClass set cacheable]} {
      $includelet mixin add ::xowiki::includelet::page_fragment_cache
    }

    if {[$includelet istype ::xowiki::Includelet]} {
      # call this always
      $includelet include_head_entries
    }

    # "render" might be cached
    set html ""
    ad_try {
      set html [$includelet render]
    } on error {errorMsg} {
      set errorCode $::errorCode
      set errorInfo $::errorInfo
      if {[string match "*for parameter*" $errorMsg]} {
        ad_return_complaint 1 [ns_quotehtml $errorMsg]
        ad_script_abort
      } else {
        ad_log error "render_includelet $includeletClass led to: $errorMsg ($errorCode)\n$errorInfo"
        set page_name [$includelet name]
        set ::errorInfo [::xowiki::Includelet html_encode $errorInfo]
        set html [:error_during_render [_ xowiki.error-includelet-error_during_render]]
      }
    }
    #:log "--include includelet returns $html"
    return $html
  }

  #   Page instproc include_portlet {arg} {
  #     :log "+++ method [self proc] of [self class] is deprecated"
  #     return [:include $arg]
  #   }

  Page ad_instproc include {-configure arg} {
    Include the html of the includelet. The method generates
    an includelet object (might be another xowiki page) and
    renders it and returns either html or an error message.
  } {
    set page [:instantiate_includelet $arg]
    if {$page eq ""} {
      # The variable 'page_name' is required by the message key
      set page_name $arg
      return [:error_during_render [_ xowiki.error-includelet-unknown]]
    }
    if {[$page istype ::xowiki::Page]} {
      set package_id [$page package_id]
      set allowed [[::$package_id set policy] check_permissions \
                       -package_id $package_id \
                       -user_id [::xo::cc set untrusted_user_id] \
                       $page view]
      if {!$allowed} {
        return "<div class='errorMsg'>Insufficient privileges to view content of [$page name].</div>"
      }
    }
    if {[info exists configure]} {
      $page configure {*}$configure
    }
    return [:render_includelet $page]
  }

  Page instproc check_adp_include_path { adp_fn } {
    #
    # For security reasons, don't allow arbitrary paths to different
    # packages.  All allowed includelets must be made available
    # under xowiki/www (preferable xowiki/www/portlets/*). When the
    # provided path contains "admin/*", admin rights are required.
    #
    if {[string match "admin/*" $adp_fn]} {
      set allowed [::xo::cc permission \
                       -object_id ${:package_id} -privilege admin \
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
    return [list allowed 1 msg "" fn /packages/[::${:package_id} package_key]/www/$adp_fn]
  }

  Page instproc include_content {arg ch2} {
    #
    # Recursion depth is a global variable to ease the deletion etc.
    #
    if {[incr ::xowiki_inclusion_depth] > 10} {
      return [:error_in_includelet $arg [_ xowiki.error-includelet-nesting_to_deep]]$ch2
    }
    if {[regexp {^adp (.*)$} $arg _ adp]} {
      try {
        lindex $adp 0
      } on error {errMsg} {
        # there is something syntactically wrong
        incr ::xowiki_inclusion_depth -1
        return [:error_in_includelet $arg [_ xowiki.error-includelet-adp_syntax_invalid]]$ch2
      }
      set adp [string map {&nbsp; " "} $adp]

      #
      # Check the provided name of the adp file
      #
      set path_info [:check_adp_include_path [lindex $adp 0]]
      #:log "path_info returned $path_info"
      if {![dict get $path_info allowed]} {
        incr ::xowiki_inclusion_depth -1
        return [:error_in_includelet $arg [dict get $path_info msg]]$ch2
      }

      set adp_fn [dict get $path_info fn]
      #
      # check the provided arguments
      #
      set adp_args [lindex $adp 1]
      if {[llength $adp_args] % 2 == 1} {
        incr ::xowiki_inclusion_depth -1
        set adp $adp_args
        incr ::xowiki_inclusion_depth -1
        return [:error_in_includelet $arg [_ xowiki.error-includelet-adp_syntax_invalid]]$ch2
      }

      lappend adp_args __including_page [self]
      set including_page_level [template::adp_level]
      ad_try {
        set page [template::adp_include $adp_fn $adp_args]
      } on error {errorMsg} {
        ad_log error "$errorMsg\n$::errorInfo"
        # in case of error, reset the adp_level to the previous value
        set ::template::parse_level $including_page_level
        return [:error_in_includelet $arg \
                    [_ xowiki.error-includelet-error_during_adp_evaluation]]$ch2
      } finally {
        incr ::xowiki_inclusion_depth -1
      }

      return $page$ch2
    } else {
      # we have a direct (adp-less include)
      set html [:include [:unescape $arg]]
      #:log "--include includelet returns $html"
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

    set normalized_name [::${:package_id} normalize_name $stripped_name]
    #:msg "input: [self args] - lang=[:lang], [:nls_language]"
    if {$lang  eq ""}   {set lang [:lang]}
    if {$name  eq ""}   {set name $lang:$normalized_name}
    #:msg result=[list name $name lang $lang normalized_name $normalized_name anchor $anchor]
    return [list name $name lang $lang normalized_name $normalized_name anchor $anchor query $query]
  }

  #
  # Forwarder to the Package instance object
  #
  Page instforward item_ref {%my package_id} %proc
  Page instforward get_ids_for_bulk_actions {%my package_id} %proc

  Page ad_instproc pretty_link {
    {-anchor ""}
    {-query ""}
    {-absolute:boolean false}
    {-siteurl ""}
    {-lang ""}
    {-download false}
    {-path_encode:boolean true}
  } {
    This method is a convenience stub for Package->pretty_link
    and can be overloaded for different pages types.

    Note that it is necessary to initialize the package before this
    method can be used.

    @param anchor anchor to be added to the link
    @param query query parameters to be added literally to the resulting URL
    @param absolute make an absolute link (including protocol and host)
    @param lang use the specified 2 character language code (rather than computing the value)
    @param download create download link (without m=download)
    @param path_encode control encoding of the url path. Returns the URL path urlencoded,
    unless path_encode is set to false.

    @return the pretty_link for the current page
    @see ::xowiki::Package instproc pretty_link
  } {
    if {${:parent_id} eq "0"} {
      set msg "you must not call pretty_link on a page with parent_id 0"
      ad_log error $msg
      error $msg
    }
    ${:package_id} pretty_link -parent_id ${:parent_id} \
        -anchor $anchor -query $query -absolute $absolute -siteurl $siteurl \
        -lang $lang -download $download -page [self] \
        -path_encode $path_encode \
        ${:name}
  }

  Page instproc detail_link {} {
    if {[info exists :instance_attributes]} {
      if {[dict exists ${:instance_attributes} detail_link]
          && [dict get ${:instance_attributes} detail_link] ne ""} {
        return [dict get ${:instance_attributes} detail_link]
      }
    }
    return [:pretty_link]
  }

  Page instproc self_link_ids {} {
    set parent_id [expr {[info exists :__ignore_self_in_links] ? ${:parent_id} : [:physical_item_id]}]
    return [list package_id [:physical_package_id] parent_id $parent_id]
  }

  Page instproc create_link {arg} {
    #:msg [self args]
    set label $arg
    set link $arg
    set options ""
    regexp {^([^|]+)[|](.*)$} $arg _ link label
    regexp {^([^|]+)[|](.*)$} $label _ label options
    set options [:unescape $options]
    set link [string trim $link]

    # Get the package_id from the provided path, and - if found -
    # return the shortened link relative to it.
    set package_id [::${:package_id} resolve_package_path $link link]
    if {$package_id == 0} {
      # we treat all such links like external links
      if {[regsub {^//} $link / link]} {
        #
        # For local links (starting with //), we provide
        # a direct treatment. JavaScript and CSS files are
        # included, images are rendered directly.
        #
        switch -glob -- [::xowiki::guesstype $link] {
          text/css {
            ::xo::Page requireCSS $link
            return ""
          }
          application/x-javascript -
          application/javascript {
            ::xo::Page requireJS $link
            return ""
          }
          image/* {
            Link create [self]::link \
                -page [self] \
                -name "" \
                -type localimage \
                -label $label \
                -href $link
            [self]::link configure {*}$options
            return [self]::link
          }
        }
      }
      set l [ExternalLink new -label $label -href $link]
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

    set link_info [:get_anchor_and_query $link]
    set parent_id [expr {$package_id == ${:package_id} ?
                         ${:parent_id} : [::$package_id folder_id]}]

    # we might consider make this configurable
    set use_package_path true
    set is_self_link false

    if {[regexp {^:(..):(.+)$} [dict get $link_info link] _ lang stripped_name]} {
      #
      # a language link (it starts with a ':')
      #
      set item_ref_info [::$package_id item_ref \
                             -use_package_path $use_package_path \
                             -default_lang [:lang] \
                             -parent_id $parent_id \
                             ${lang}:$stripped_name]
      dict set item_ref_info link_type language

    } elseif {[regexp {^[.]SELF[.]/(.*)$} [dict get $link_info link] _ link]} {
      #
      # Remove ".SELF./" from the path and search for the named
      # resource (e.g. the image name) under the current (physical)
      # item.
      #
      set self_link_ids [:self_link_ids]
      set parent_id  [dict get $self_link_ids parent_id]
      set package_id [dict get $self_link_ids package_id]

      #ns_log notice "SELF-LINK '[dict get $link_info link]' in TEXT resolve with parent $parent_id"
      set is_self_link true
      set item_ref_info [::$package_id item_ref \
                             -use_package_path $use_package_path \
                             -default_lang [:lang] \
                             -parent_id $parent_id \
                             $link]
      dict set link_info link $link
      #:log "SELF-LINK returns $item_ref_info"

    } else {
      #
      # A plain link, search relative to the parent.
      #
      #ns_log notice "PLAIN-LINK '[dict get $link_info link]' in TEXT resolve with parent $parent_id"
      set item_ref_info [::$package_id item_ref \
                             -use_package_path $use_package_path \
                             -default_lang [:lang] \
                             -parent_id $parent_id \
                             [dict get $link_info link]]
    }
    #ns_log notice "link_info $link_info"
    #ns_log notice "--L link <$arg> lang [:lang] CURRENT ${:name} nls_lang ${:nls_language} -> item_ref_info $item_ref_info"

    #:log "link '[dict get $link_info link]' package_id $package_id ${:package_id} => [array get {}]"

    if {$label eq $arg} {
      set label [dict get $link_info link]
    }

    set item_name [string trimleft [dict get $item_ref_info prefix]:[dict get $item_ref_info stripped_name] :]
    Link create [self]::link \
        -page [self] \
        -form [dict get $item_ref_info form] \
        -type [dict get $item_ref_info link_type] \
        -name $item_name \
        -lang [dict get $item_ref_info prefix] \
        -anchor [dict get $link_info anchor] \
        -query [dict get $link_info query] \
        -stripped_name [dict get $item_ref_info stripped_name] \
        -label $label \
        -parent_id [dict get $item_ref_info parent_id] \
        -item_id [dict get $item_ref_info item_id] \
        -package_id $package_id \
        -is_self_link $is_self_link

    # in case, we can't link, flush the href
    if {[:can_link [dict get $item_ref_info item_id]] == 0} {
      :references refused [dict get $item_ref_info item_id]
      if {[[self]::link exists href]} {
        [self]::link unset href
      }
    }

    [self]::link configure {*}$options
    set result [[self]::link]

    return $result
  }

  Page instproc new_link {
    -object_type
    -name
    -title
    -nls_language
    -return_url
    -parent_id
    page_package_id
  } {
    if {[info exists parent_id] && $parent_id eq ""} {
      unset parent_id
    }
    return [::$page_package_id make_link $page_package_id \
                edit-new object_type name title nls_language return_url parent_id autoname]
  }

  FormPage instproc new_link {
    -object_type
    -name
    -title
    -nls_language
    -parent_id
    -return_url
    page_package_id
  } {
    if {[info exists object_type]} {
      next
    } else {
      set template_id ${:page_template}
      if {![info exists parent_id]} {
        set parent_id [::$page_package_id folder_id]
      }
      set form [::$page_package_id pretty_link -parent_id $parent_id [::$template_id name]]
      return [::$page_package_id make_link -link $form $template_id \
                  create-new return_url name title nls_language]
    }
  }

  #
  # Handling page references. Use like e.g.
  #
  #   $page references clear
  #   $page references resolved [list $item_id [:type]]
  #   $page references get resolved
  #   $page references all
  #
  Page instproc references {submethod args} {
    #ns_log notice "---- ${:name} references $submethod $args"
    switch -- $submethod {
      clear {
        set :__references { unresolved {} resolved {} refused {} }
      }
      unresolved -
      refused -
      resolved {
        return [dict lappend :__references $submethod [lindex $args 0]]
      }
      get { return [dict get ${:__references} [lindex $args 0]] }
      all { return ${:__references} }
      default {error "unknown submethod: $submethod"}
    }
  }

  Page instproc anchor_parent_id {} {
    #
    # This method returns the parent_id used for rendering links
    # between double square brackets [[...]]. It can be overloaded for
    # more complex embedding situations
    #
    return ${:item_id}
  }

  Page instproc anchor {arg} {
    ad_try {
      set l [:create_link $arg]
    } on error {errorMsg} {
      return "<div class='errorMsg'>Error during processing of anchor ${arg}:<blockquote>$errorMsg</blockquote></div>"
    }
    if {$l eq ""} {
      return ""
    }

    if {[info exists :__RESOLVE_LOCAL] && [$l exists is_self_link] && [$l is_self_link]} {
      :set_resolve_context -package_id [:physical_package_id] -parent_id [:physical_parent_id]
      $l parent_id [:anchor_parent_id]
      set html [$l render]
      :reset_resolve_context
    } else {
      set html [$l render]
    }

    if {[info commands $l] ne ""} {
      $l destroy
    } else {
      ns_log notice "link object already destroyed. This might be due to a recursive inclusion"
    }
    return $html
  }


  Page instproc substitute_markup {{-context_obj ""} content} {
    if {${:mime_type} eq "text/enhanced"} {
      set content [ad_enhanced_text_to_html $content]
    }
    if {!${:do_substitutions}} {
      return $content
    }
    #
    # The provided content and the returned result are strings
    # containing HTML (unless we have other rich-text encodings).
    #
    # First get the potentially class specific regular expression
    # definitions.
    #
    set baseclass [expr {[[:info class] exists RE] ? [:info class] : [self class]}]
    $baseclass instvar RE markupmap
    #:log "-- baseclass for RE = $baseclass"

    #
    # Secondly, iterate line-wise over the text.
    #
    set output ""
    set l ""

    ad_try {
      if {$context_obj ne ""} {
        :set_resolve_context \
            -package_id [$context_obj package_id] -parent_id [$context_obj item_id]
        set :__ignore_self_in_links 1
      }

      foreach l0 [split $content \n] {
        append l [string map $markupmap(escape) $l0]
        if {[string first \{\{ $l] > -1 && [string first \}\} $l] == -1} {append l " "; continue}
        set l [:regsub_eval $RE(anchor)  $l {:anchor  "\1"} "1"]
        set l [:regsub_eval $RE(div)     $l {:div     "\1"}]
        set l [:regsub_eval $RE(include) $l {:include_content "\1" "\2"}]
        #regsub -all -- $RE(clean) $l {\1} l
        regsub -all -- $RE(clean2) $l { \1} l
        set l [string map $markupmap(unescape) $l]
        append output $l \n
        set l ""
      }
    } on error {errorMsg} {
      error $errorMsg
    } finally {
      if {$context_obj ne ""} {
        unset :__ignore_self_in_links
        :reset_resolve_context
      }
    }
    #:log "--substitute_markup returns $output"
    return $output
  }


  Page instproc adp_subst {content} {
    #
    # The provided content and the returned result are strings
    # containing HTML.
    #
    #:msg "--adp_subst in ${:name} vars=[:info vars]"
    foreach __v [:info vars] {
      if {[info exists $__v]} continue
      #ns_log notice "import instvar $__v into current scope"
      :instvar $__v
    }
    #
    # The following block imports variables from the class to the
    # instance. Not sure, why we want this. TODO: Comment or remove.
    #
    #set __ignorelist {RE __defaults name_method object_type_key db_slot}
    #set __my_class [:info class]
    #foreach __v [$__my_class info vars] {
    #  if {[info exists $__v] || $__v in $__ignorelist} continue
    #  ns_log notice "import from $__my_class var $__v into [self]"
    #  $__my_class instvar $__v
    #}
    set __ignorelist {
      __v __vars __l __ignorelist __varlist __references __my_class
      __last_includelet text item_id content lang_links
    }

    # set variables current_* to ease personalization
    set current_user [::xo::cc set untrusted_user_id]
    set current_url [::xo::cc url]

    set __vars [info vars]
    regsub -all -- [template::adp_variable_regexp] $content {\1@\2;noquote@} content_noquote
    #:log "--adp before adp_eval '[template::adp_level]'"

    set __l [string length $content]
    try {
      set __bufsize [ns_adp_ctl bufsize]
    } on error {errorMsg} {
      #
      # The adp buffer has limited size. For large pages, it might happen
      # that the buffer overflows. In AOLserver 4.5, we can increase the
      # buffer size. In 4.0.10, we are out of luck.
      #
      set __bufsize 0
    }
    if {$__bufsize > 0 && $__l > $__bufsize} {
      #
      # We have AOLserver 4.5 or NaviServer , we can increase the
      # bufsize
      #
      ns_adp_ctl bufsize [expr {$__l + 1024}]
    }
    set template_code [template::adp_compile -string $content_noquote]
    set my_parse_level [template::adp_level]
    ad_try {
      set template_value [template::adp_eval template_code]
    } on error {__errMsg} {
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
      #:log "--adp after adp_eval '[template::adp_level]' mpl=$my_parse_level"
      set template_value "<div class='errorMsg'>Error in Page $name: $__errMsg</div>$content<p>Possible values are$__template_variables__"
    }
    return $template_value
  }

  Page instproc get_description {-nr_chars content} {
    set revision_id ${:revision_id}
    set description ${:description}
    if {$description eq "" && $content ne ""} {
      set description [ad_html_text_convert -from text/html -to text/plain -- $content]
    }
    if {$description eq "" && $revision_id > 0} {
      set body [::xo::dc get_value -prepare integer get_description_from_syndication \
                    "select body from syndication where object_id = :revision_id" \
                    -default ""]
      set description [ad_html_text_convert -from text/html -to text/plain -- $body]
    }
    if {[info exists nr_chars] && [string length $description] > $nr_chars} {
      set description [string range $description 0 $nr_chars]...
    }
    return $description
  }

  Page instproc render_content {} {
    #:log "-- '${:text}'"
    lassign ${:text} html mime
    if {[:render_adp]} {
      set html [:adp_subst $html]
    }
    return [:substitute_markup $html]
  }

  Page instproc set_content {text} {
    :text [list [string map [list >> "\n&gt;&gt;" << "&lt;&lt;\n"] \
                     [string trim $text " \n"]] text/html]
  }

  Page instproc get_rich_text_spec {field_name default} {
    set package_id ${:package_id}
    set spec ""
    #:msg WidgetSpecs=[::$package_id get_parameter WidgetSpecs]
    foreach {s widget_spec} [::$package_id get_parameter WidgetSpecs] {
      lassign [split $s ,] page_name var_name
      # in case we have no name (edit new page) we use the first value or the default.
      set name [expr {[info exists :name] ? ${:name} : $page_name}]
      #:msg "--w T.name = '$name' var=$page_name ([string match $page_name $name]), $var_name $field_name ([string match $var_name $field_name])"
      if {[string match $page_name $name] &&
          [string match $var_name $field_name]} {
        set spec $widget_spec
        #:msg "setting spec to $spec"
        break
      }
    }
    if {$spec eq ""} {
      return $default
    }
    return $field_name:$spec
  }

  Page instproc validate=name {name} {
    #:log "---- validate=name $name is called"
    upvar nls_language nls_language
    set success [::xowiki::validate_name [self]]
    if {$success} {
      set actual_length [string length $name]
      set max_length 400
      if {$actual_length > $max_length} {
        set errorMsg [_ acs-tcl.lt_name_is_too_long__Ple \
                          [list name $name max_length $max_length actual_length $actual_length]]
        set success 0
      }
    } else {
      set errorMsg [_ xowiki.Page-validate_name-duplicate_item [list value $name]]
    }

    if {$success} {
      #
      # Set the instance variable with a potentially prefixed
      # name. The classical validators (like xowiki::validate_name) do
      # just an upvar. Therefore, the "name" value is already
      # normalized and prefixed.
      #
      set :name $name
    } else {
      uplevel [list set errorMsg $errorMsg]
    }
    return $success
  }

  Page instproc validate=page_order {value} {
    if {[info exists :page_order]} {
      set page_order [string trim $value " ."]
      set :page_order $page_order
      # :log "validate=page_order '$value' -> '$page_order'"
      return [expr {![regexp {[^0-9a-zA-Z_.]} $page_order]}]
    }
    return 1
  }

  Page instproc references_update {resolved {unresolved {}}} {
    #:log "references_update resolved '$resolved' unresolved '$unresolved'"
    set item_id ${:item_id}
    ::xo::dc dml -prepare integer delete_references \
        "delete from xowiki_references where page = :item_id"
    ::xo::dc dml -prepare integer delete_unresolved_references \
        "delete from xowiki_unresolved_references where page = :item_id"
    foreach ref $resolved {
      lassign $ref r link_type
      ::xo::dc dml insert_reference \
          "insert into xowiki_references (reference, link_type, page) \
           values (:r,:link_type,:item_id)"
    }
    foreach ref $unresolved {
      dict with ref {
        ::xo::dc dml insert_unresolved_reference \
            "insert into xowiki_unresolved_references (page, parent_id, name, link_type) \
            values (:item_id,:parent_id,:name,:link_type)"
      }
    }
  }

  Page instproc check_unresolved_references {} {
    #:log "check_unresolved_references: name ${:name} parent_id ${:parent_id}"
    set parent_id ${:parent_id}
    set name ${:name}
    foreach i [xo::dc list -prepare integer,text items_with_unresolved_references {
      SELECT page from xowiki_unresolved_references
      WHERE  parent_id = :parent_id
      AND    name = :name
    }] {
      set page [::xo::db::CrClass get_instance_from_db -item_id $i]
      #:log "==== check_unresolved_references found page [$page name] with a broken reference to the new page ${:name}"
      $page render -update_references all -with_footer false
    }
  }

  Page proc container_already_rendered {field} {
    if {![info exists ::xowiki_page_item_id_rendered]} {
      return ""
    }
    #:log "--OMIT and not $field in ([ns_dbquotelist $::xowiki_page_item_id_rendered])"
    return "and not $field in ([ns_dbquotelist $::xowiki_page_item_id_rendered])"
  }

  Page instproc htmlFooter {{-content ""}} {
    if {[info exists :__no_footer]} {return ""}
    set package_id ${:package_id}
    set footer ""

    if {[ns_conn isconnected]} {
      set url         "[ns_conn location][::xo::cc url]"
      set package_url "[ns_conn location][::$package_id package_url]"
    }

    set tags ""
    if {[::$package_id get_parameter "with_tags" 1] &&
        ![:exists_query_parameter no_tags] &&
        [::xo::cc user_id] != 0
      } {
      set tag_content [:include my-tags]
      set tag_includelet ${:__last_includelet}
      if {[$tag_includelet exists tags]} {
        set tags [$tag_includelet set tags]
      }
    } else {
      set tag_content ""
    }

    if {[::$package_id get_parameter "with_digg" 0] && [info exists url]} {
      if {![info exists description]} {set description [:get_description $content]}
      append footer "<div style='float: right'>" \
          [:include [list digg -description $description -url $url]] "</div>\n"
    }

    if {[::$package_id get_parameter "with_delicious" 0] && [info exists url]} {
      if {![info exists description]} {set description [:get_description $content]}
      append footer "<div style='float: right; padding-right: 10px;'>" \
          [:include [list delicious -description $description -url $url -tags $tags]] \
          "</div>\n"
    }

    if {[::$package_id get_parameter "with_yahoo_publisher" 0] && [info exists package_url]} {
      set publisher [::$package_id get_parameter "my_yahoo_publisher" \
                         [::xo::get_user_name [::xo::cc user_id]]]
      append footer \
          "<div style='float: right; padding-right: 10px;'>" \
          [:include [list my-yahoo-publisher \
                         -publisher $publisher \
                         -rssurl "$package_url?rss"]] \
          "</div>\n"
    }

    if {[::$package_id get_parameter "show_page_references" 1]} {
      append footer [:include my-references]
    }

    if {[::$package_id get_parameter "show_per_object_categories" 1]} {
      set html [:include my-categories]
      if {$html ne ""} {
        append footer $html <br>
      }
      set categories_includelet ${:__last_includelet}
    }

    append footer $tag_content

    if {[::$package_id get_parameter "with_general_comments" 0] &&
        ![:exists_query_parameter no_gc]} {
      append footer [:include my-general-comments]
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
    return [:render -with_footer false -update_references never]
  }

  Page ad_instproc render {
    {-update_references unresolved}
    {-with_footer:boolean true}
  } {

    Render a wiki page with some optional features, such as including
    a footer or updating references for this page.

    @param update_references might be "all", "unresolved" or "never"
    @param with_footer boolean value
    @return rendered HTML content.
  } {
    #
    # prepare language links
    #
    array set :lang_links {found "" undefined ""}
    #
    # prepare references management
    #
    :references clear
    if {[info exists :__extra_references]} {
      #
      # xowiki content-flow uses extra references, e.g. to forms.
      # TODO: provide a better interface for providing these kind of
      # non-link references.
      #
      foreach ref ${:__extra_references} {
        :references resolved $ref
      }
      unset :__extra_references
    }
    #
    # Get page content and care about reference management.
    #
    set content [:render_content]
    #
    # Clear old reference and record new ones in cases updating
    # references is activated "always" or just for unresolved
    # references.
    #
    set unresolved_references [:references get unresolved]

    if {$update_references eq "all"
        || ($update_references eq "unresolved" && [llength $unresolved_references] > 0)
      } {
      :references_update \
          [lsort -unique [:references get resolved]] \
          [lsort -unique $unresolved_references]
    }
    #
    #:log "Page ${:name} render with_footer $with_footer - [ns_conn isconnected] - [catch {ns_conn content}]"
    #
    # handle footer
    #
    if {$with_footer && [::xo::cc get_parameter content-type text/html] eq "text/html"} {
      append content "<DIV class='content-chunk-footer'>"
      if {![info exists :__no_footer] && ![::xo::cc get_parameter __no_footer 0]} {
        append content [:footer]
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
  #   ${:object} proc search_render {} {
  #        return [list html "Hello World" keywords "hello world"]
  #   }
  #
  #
  Page instproc search_render {} {
    set :__no_form_page_footer 1
    set html [:render -update_references none]
    unset :__no_form_page_footer

    foreach tag {h1 h2 h3 h4 h5 b strong} {
      foreach {match words} [regexp -all -inline "<$tag>(\[^<\]+)</$tag>" $html] {
        foreach w [split $words] {
          if {$w eq ""} continue
          set word($w) 1
        }
      }
    }
    foreach tag [::xowiki::Page get_tags -package_id ${:package_id} -item_id ${:item_id}] {
      set word($tag) 1
    }
    #:log [list html $html keywords [array names word]]
    return [list mime text/html html $html keywords [array names word] text ""]
  }

  #
  # The method "notification_render" is called by the notification
  # procs.  By re-defining this method (e.g. in a workflow), it is
  # possible to produce a different notification text.
  # The method returns an HTML text.
  #
  Page instproc notification_render {} {
    return [:render]
  }

  FormPage instproc notification_render {} {
    if {[:is_link_page] || [:is_folder_page]} {
      return ""
    } else {
      return [next]
    }
  }

  #
  # The method "notification_notify" calls typically the notification
  # updater on the current page. It might be used as well to trigger
  # notifications on other pages (in other maybe packages), when the
  # page content is e.g. linked.
  #
  Page instproc notification_notify {} {
    ::xowiki::notification::do_notifications -page [self]
  }

  #
  # The method "notification_detail_link" is called from
  # do_notifications to provide a link back to the context, where the
  # new/modified item can be viewed in detail. It has to return an
  # html and a text component.
  #
  Page instproc notification_detail_link {} {
    set link [:pretty_link -absolute 1]
    append html "<p>For more details, see <a href='[ns_quotehtml $link]'>[ns_quotehtml ${:title}]</a></p>"
    append text "\nFor more details, see $link ...\n"
    return [list html $html text $text]
  }

  #
  # The method "notification_subject" is called from
  # do_notifications to provide the subject line for notifications.
  # The "-category_label" might be empty.
  #
  Page instproc notification_subject {-instance_name {-category_label ""} -state} {
    if {$category_label eq ""} {
      return "\[$instance_name\]: ${:title} ($state)"
    } else {
      return "\[$instance_name\] $category_label: ${:title} ($state)"
    }
  }

  #
  # Update xowiki_last_visited table
  #
  Page instproc record_last_visited {-user_id} {
    set item_id ${:item_id}
    set package_id ${:package_id}
    if {![info exists user_id]} {set user_id [::xo::cc set untrusted_user_id]}
    if {$user_id > 0} {
      # only record information for authenticated users
      ::xo::dc transaction {
        set rows [xo::dc dml -prepare integer,integer update_last_visisted {
          update xowiki_last_visited set time = CURRENT_TIMESTAMP, count = count + 1
          where page_id = :item_id and user_id = :user_id
        }]
        if {$rows ne "" && $rows < 1} {
          ::xo::dc dml insert_last_visisted \
              "insert into xowiki_last_visited (page_id, package_id, user_id, count, time) \
               values (:item_id, :package_id, :user_id, 1, CURRENT_TIMESTAMP)"
        }
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

  Page instproc content_header_append {text} {
    #
    # This function is to be called on pages that want to prepend
    # content prior to the main content. This is especially important
    # for HTML forms (e.g. produced by the xowiki::Form renderer),
    # where the form-body is not allowed to contain nested forms.
    #
    append ::__xowiki__content_header $text \n
  }

  Page instproc content_header_get {} {
    if {[info exists ::__xowiki__content_header]} {
      return $::__xowiki__content_header
    }
  }


  Page instproc form_field_index {form_field_objs} {
    set marker ::__computed_form_field_names($form_field_objs)
    if {[info exists $marker]} return

    foreach form_field_obj $form_field_objs {
      if {![$form_field_obj istype ::xowiki::formfield::FormField]} continue
      set ::_form_field_names([$form_field_obj name]) $form_field_obj
      :form_field_index [$form_field_obj info children]
    }
    set $marker 1
  }

  Page instproc form_field_flush_cache {} {
    #
    # Flush all cached form_field_names.
    #
    array unset ::_form_field_names
  }

  Page instproc form_field_exists {name} {
    return [info exists ::_form_field_names($name)]
  }

  Page instproc __debug_known_field_names {msg} {
    set fields {}
    foreach name [lsort [array names ::_form_field_names]] {
      set f $::_form_field_names($name)
      append fields "  $name\t[$f info class]\t [$f spec]\n"
    }
    append fields "Repeat container:\n"
    foreach f [::xowiki::formfield::repeatContainer info instances] {
      append fields "$f\t[$f name]\t [$f spec]\n"
      foreach component [$f components] {
        append fields "... [$component name]\t[$component info class]\t [$component spec]\n"
        if {[$component istype ::xowiki::formfield::CompoundField]} {
          foreach c [$component components] {
            append fields "..... [$c name]\t[$c info class]\t [$c spec]\n"
          }
        }
      }
    }
    #ns_log notice "dynamic repeat field $msg: fields & specs:\n$fields"
  }

  Page instproc lookup_form_field {
    -name:required
    form_fields
  } {
    :form_field_index $form_fields
    #ns_log notice "lookup_form_field <$name>"

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
    foreach name_and_spec [:get_form_constraints] {
      regexp {^([^:]+):(.*)$} $name_and_spec _ spec_name short_spec

      if {[string match $spec_name $name]} {
        set f [:create_form_fields_from_form_constraints [list $name:$short_spec]]
        set $key $f
        return $f
      }
    }

    #
    # Maybe, this was a repeat field, and we have to create the nth
    # component dynamically.
    #
    set components [split $name .]
    set path [lindex $components 0]
    #ns_log notice "dynamic repeat field name '$name' -> components <$components>"

    foreach c [lrange $components 1 end] {
      if {[string is integer -strict $c]} {
        # this looks like a repeat component
        #ns_log notice "dynamic repeat field root <$path> number $c exists? [info exists ::_form_field_names($path)]"

        if {[info exists ::_form_field_names($path)]} {
          #
          # The root field exists, so add the component.
          #
          set repeatField [set ::_form_field_names($path)]
          #
          # Add all components from 1 to specified number to the list,
          # unless restricted by the max value. This frees us from
          # potential problems, when the browser sends the form fields
          # in an unexpected order. The resulting components will be
          # always in the numbered order.
          #
          set max [$repeatField max]
          if {$max > $c} {
            set max $c
          }
          for {set i 1} {$i <= $max} {incr i} {
            if {![info exists ::_form_field_names($path.$i)]} {
              set f [$repeatField require_component $i]
              #ns_log notice "dynamic repeat field created $path.$i -> $f"
              :form_field_index $f
            }
          }
        } else {
          :__debug_known_field_names "<$path> needed to create <$path.$c>"
        }
      }
      append path . $c
    }
    #
    # We might have created in the loop above the required
    # formfield. If so, return it.
    #
    if {[info exists $key]} {
      #ns_log notice "dynamic repeat 2nd lookup for $key succeeds"
      return [set $key]
    }

    if {$name ni {langmarks fontname fontsize formatblock} && ![string match *__locale $name]} {
      set names [list]
      #xo::show_stack
      foreach f $form_fields {lappend names [$f name]}
      :msg "No form field with name '$name' found\
            (available fields: [lsort [array names ::_form_field_names]])"
      ns_log warning "====== lookup_form_field: No form field with name '$name' found" \
          "(available fields: [lsort [array names ::_form_field_names]])"
    }
    set f [:create_form_fields_from_form_constraints [list $name:text]]
    set $key $f
    return $f
  }

  Page instproc lookup_cached_form_field {
    -name:required
  } {
    set key ::_form_field_names($name)
    #:msg "FOUND($name)=[info exists $key]"
    if {[info exists $key]} {
      return [set $key]
    }
    error "No form field with name $name found"
  }

  Page instproc show_fields {form_fields {msg ""}} {
    # this method is for debugging only
    foreach f $form_fields { append msg "[$f name] [namespace tail [$f info class]], " }
    :msg $msg
    :log "form_fields: $msg"
  }



  Page instproc translate {-from -to text} {
    set langpair $from|$to
    set url http://translate.google.com/#$from/$to/$text
    set request [util::http::get -url $url]
    set status [dict get $request status]
    set data [expr {[dict exists $request page] ? [dict get $request page] : ""}]

    #:msg status=[$r set status]
    if {$status == 200} {
      #:msg data=$data
      dom parse -html -simple $data doc
      $doc documentElement root
      set n [$root selectNodes {//*[@id="result_box"]}]
      :msg "$text $from=>$to node '$n'"
      if {$n ne ""} {return [$n asText]}
    }
    util_user_message -message "Could not translate text, \
        status=$status"
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
    {-state initial}
    {-creation_user ""}
    {-publish_status production}
    {-source_item_id ""}
  } {
    set ia [dict merge [:default_instance_attributes] $instance_attributes]

    if {$nls_language eq ""} {
      set nls_language [:query_parameter nls_language:wordchar [:nls_language]]
    }
    #
    # Take the value of the instance variables package_id and
    # parent_id as default.
    #
    if {![info exists package_id]} {
      set package_id ${:package_id}
    }
    if {![info exists parent_id]}  {
      set parent_id ${:parent_id}
    }

    if {$creation_user eq ""} {
      #
      # When no creation_user is provided, take the current user_id,
      # but take care as well for situations, where no connections is
      # available.
      #
      set context [::$package_id context]
      if {![nsf::is object $context]} {
        ::xo::ConnectionContext require \
            -package_id $package_id \
            -url [::$package_id pretty_link ${:name}]
      }
      set creation_user [$context user_id]
    }

    set f [FormPage new -destroy_on_cleanup \
               -name $name \
               -text $text \
               -package_id $package_id \
               -parent_id $parent_id \
               -nls_language $nls_language \
               -publish_status $publish_status \
               -creation_user $creation_user \
               -state $state \
               -instance_attributes $ia \
               -page_template ${:item_id}]

    # Make sure to load the instance attributes
    #$f array set __ia [$f instance_attributes]

    #
    # Call the application specific initialization, when a FormPage is
    # initially created. This is used to control the life-cycle of
    # FormPages.
    #
    $f initialize

    #
    # If we copy an item, we use source_item_id to provide defaults.
    #
    if {$source_item_id ne ""} {
      set source [FormPage get_instance_from_db -item_id $source_item_id]
      $f copy_content_vars -from_object $source
      #set name "[::xowiki::autoname new -parent_id $source_item_id -name ${:name}]"
      #::$package_id get_lang_and_name -name $name lang name
      #$f set name $name
      #ns_log notice "FINAL NAME <$name>"
      #:msg nls=[$f nls_language],source-nls=[$source nls_language]
    }
    foreach {att value} $default_variables {
      $f set $att $value
    }

    #
    # Finally provide base for auto-titles.
    #
    $f set __title_prefix ${:title}

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
    set html ${:text}
    if {[:render_adp]} {
      set html [:adp_subst $html]
    }
    return [:substitute_markup $html]
  }
  PlainPage instproc set_content {text} {
    set :text $text
  }

  PlainPage instproc substitute_markup {{-context_obj ""} raw_content} {

    #
    # The provided text is a raw text that is transformed into HTML
    # markup for links etc.
    #
    [self class] instvar RE markupmap
    if {!${:do_substitutions}} {
      return $raw_content
    }
    set html ""
    try {
      if {$context_obj ne ""} {
        :set_resolve_context \
            -package_id [$context_obj package_id] -parent_id [$context_obj item_id]
      }
      foreach l [split $raw_content \n] {
        set l [string map $markupmap(escape) $l]
        set l [:regsub_eval $RE(anchor)  $l {:anchor  "\1"}]
        set l [:regsub_eval $RE(div)     $l {:div     "\1"}]
        set l [:regsub_eval $RE(include) $l {:include_content "\1" ""}]
        #regsub -all -- $RE(clean) $l {\1} l
        set l [string map $markupmap(unescape) $l]
        append html $l \n
      }
    } on error {errorMsg} {
      error $errorMsg
    } finally {
      if {$context_obj ne ""} {
        :reset_resolve_context
      }
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
    return file:[::${:package_id} normalize_name $stripped_name]
  }
  File instproc full_file_name {} {
    if {![info exists :full_file_name]} {
      if {[info exists :revision_id]} {
        #
        # For a given revision_id, the full_file_name will never
        # change.  Therefore, we can easily cache the full filename
        # for the revision_id.
        #
        set :full_file_name [::xowiki::cache eval -partition_key ${:revision_id} ffn-${:revision_id} {
          return [content::revision::get_cr_file_path -revision_id ${:revision_id}]
        }]
        #:log "--F setting full-file-name of ${:revision_id}  ${:full_file_name}"
      }
    }
    return ${:full_file_name}
  }

  File instproc search_render {} {
    #  array set "" {mime text/html text "" html "" keywords ""}
    if {${:mime_type} eq "text/plain"} {
      set f [open [:full_file_name] r]; set data [read $f]; close $f
      set result [list text $data mime text/plain]
    } elseif {[::namespace which ::search::convert::binary_to_text] ne ""} {
      set txt [search::convert::binary_to_text \
                   -filename [:full_file_name] \
                   -mime_type ${:mime_type}]
      set result [list text $txt mime text/plain]
    } else {
      set result [list text "" mime text/plain]
    }

    #ns_log notice "search_render returns $result"
    return $result
  }

  File instproc html_content {{-add_sections_to_folder_tree 0} -owner} {
    set parent_id ${:parent_id}
    set fileName [:full_file_name]

    set f [open $fileName r]; set data [read $f]; close $f

    # Ugly hack to fight against a problem with tDom: asHTML strips
    # spaces between a </span> and the following <span>"
    #regsub -all -- "/span>      <span" $data "/span>\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;<span" data
    #regsub -all -- "/span>     <span" $data "/span>\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;<span" data
    #regsub -all -- "/span>    <span" $data "/span>\\&nbsp;\\&nbsp;\\&nbsp;\\&nbsp;<span" data
    #regsub -all -- "/span>   <span" $data "/span>\\&nbsp;\\&nbsp;\\&nbsp;<span" data
    #regsub -all -- "/span>  <span" $data "/span>\\&nbsp;\\&nbsp;<span" data

    regsub -all -- "/span> " $data "/span>\\&nbsp;" data
    regsub -all -- " <span " $data "\\&nbsp;<span " data
    regsub -all -- "/span>\n<span " $data "/span><br><span " data
    regsub -all -- "/span>\n\n<span " $data "/span><br><br><span " data

    dom parse -simple $data doc
    $doc documentElement root

    #
    # substitute relative links to download links in the same folder
    #
    set prefix [::$parent_id pretty_link -absolute true -download true]
    foreach n [$root selectNodes //img] {
      set src [$n getAttribute src]
      if {[regexp {^[^/]} $src]} {
        $n setAttribute src $prefix/$src
        #:msg "setting src to $prefix/$src"
      }
    }

    #
    # In case, the switch is activated, and we have a menubar, add the
    # top level section
    #
    if {$add_sections_to_folder_tree && [nsf::is object ::__xowiki__MenuBar]} {
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
    set parent_id ${:parent_id}
    set package_id ${:package_id}
    # don't require permissions here, such that rss can present the link
    #set page_link [::$package_id make_link -privilege public [self] download ""]

    set ctx [::$package_id context]
    set revision_id [$ctx query_parameter revision_id:intger]
    set query [expr {$revision_id ne "" ? "revision_id=$revision_id" : ""}]
    set page_link [:pretty_link -download true -query $query]
    if {[$ctx query_parameter html-content] ne ""} {
      return [:html_content]
    }

    #:log "--F page_link=$page_link ---- "
    set t [TableWidget new -volatile \
               -columns {
                 AnchorField name -label [_ xowiki.Page-name]
                 Field mime_type -label "#xowiki.content_type#"
                 Field last_modified -label "#xowiki.Page-last_modified#"
                 Field mod_user -label "#xowiki.By_user#"
                 Field size -label "#xowiki.Size# (Bytes)"
               }]

    regsub {[.][0-9]+([^0-9])} ${:last_modified} {\1} last_modified
    ::$package_id get_lang_and_name -name ${:name} lang stripped_name
    set label $stripped_name

    $t add \
        -name $stripped_name \
        -mime_type ${:mime_type} \
        -name.href $page_link \
        -last_modified $last_modified \
        -mod_user [::xo::get_user_name ${:creation_user}] \
        -size [file size [:full_file_name]]

    switch -glob ${:mime_type} {
      image/* {
        set l [Link new \
                   -page [self] -query $query \
                   -type image -name ${:name} -lang "" \
                   -stripped_name $stripped_name -label $label \
                   -parent_id $parent_id -item_id ${:item_id} -package_id $package_id]
        set preview "<div >[$l render]</div>"
        $l destroy
      }
      text/plain {
        set text [::xo::read_file [:full_file_name]]
        set preview "<pre class='code'>[::xowiki::Includelet html_encode $text]</pre>"
      }
      default {set preview ""}
    }
    return "$preview[$t asHTML]\n<p>${:description}</p>"
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
      append content "<li><em>$label:</em> [set :$var]\n"
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
                -item_id ${:item_id} -publish_status $publish_status]
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
            where page_template = :item_id \
                        $publish_status_clause $package_clause $parent_id_clause \
                        and page_instance_id = coalesce(i.live_revision,i.latest_revision)"]
    return $count
  }

  Page instproc css_class_name {{-margin_form:boolean true}} {
    #
    # Determine the CSS class name for xowiki forms
    #
    set name ""
    if {$margin_form} {
      set css [::xowiki::CSS class margin-form]
      if {$css ne ""} {
        set name "$css "
      }
    }
    return [append name [::xowiki::utility formCSSclass ${:name}]]
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
        :log "can't parse $spec in attribute and value; ignoring"
      }
    }
    return $result
  }

  PageInstance proc get_short_spec_from_form_constraints {-name -form_constraints} {
    #
    # For the time being we cache the parsed form_constraints. Without
    # caching, the proc takes 87 microseconds, with chaching, it is
    # significantly faster.
    #
    # via ns_cache {6.153537846215379 microseconds per iteration}
    # via nsv {3.865795920407959 microseconds per iteration}
    #
    set varname ::__xo_[ns_md5 $form_constraints]
    set dict ""

    if {![nsv_get parsed_fcs $varname dict]} {
      #
      # Not parsed yet
      #
      foreach name_and_spec $form_constraints {
        set p [string first : $name_and_spec]
        if {$p > -1} {
          dict set dict \
              [string range $name_and_spec 0 $p-1] \
              [string range $name_and_spec $p+1 end]
        } else {
          ad_log warning "get_short_spec_from_form_constraints: name_and_spec <$name_and_spec> is invalid"
        }
      }
      nsv_set parsed_fcs $varname $dict
    }
    if {[dict exists $dict $name]} {
      return [dict get $dict $name]
    }
    return ""
  }
  #
  # Set the nsv array parsed_fcs to dummy values to avoid potential
  # exceptions on operations requiring its existence.
  #
  nsv_set parsed_fcs . .

  PageInstance instproc field_names_from_form_constraints {} {
    set form_constraints [:get_form_constraints]
    set result {}
    foreach name_and_spec $form_constraints {
      regexp {^([^:]+):} $name_and_spec _ name
      if {[string range $name 0 0] eq "@"} {
        # return no aggregated (pseudo) form field names
        continue
      }
      lappend result $name
    }
    return $result
  }

  PageInstance instproc get_short_spec {{-form_constraints ""} name} {
    #
    # In case, the form_constraints are provided, get the short-spec
    # from there, otherwise compute form_constraints via
    # method "get_form_constraints".
    #
    if {$form_constraints eq ""} {
      set form_constraints [:get_form_constraints]
    }
    if {$form_constraints ne ""} {
      set s [::xowiki::PageInstance get_short_spec_from_form_constraints \
                 -name $name -form_constraints $form_constraints]
      #:msg "get_short_spec $name c=$form_constraints => '$s'"
      return $s
    }
    return ""
  }

  PageInstance instproc get_field_label {name value} {
    set short_spec [:get_short_spec $name]
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
    foreach {s widget_spec} [::${:package_id} get_parameter WidgetSpecs] {
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
    #:log "--w"
    # get widget spec from folder (highest priority)
    set spec [:widget_spec_from_folder_object $name [${:page_template} set name]]
    if {$spec ne ""} {
      return $spec
    }
    # get widget spec from attribute definition
    set f [:create_raw_form_field -name $name -slot [:find_slot $name]]
    if {$f ne ""} {
      return [$f asWidgetSpec]
    }
    # use default widget spec
    return $default_spec
  }

  PageInstance instproc get_form {} {
    # get the (HTML) form of the ::xowiki::PageTemplates/::xowiki::Form
    return [:get_html_from_content [:get_from_template form]]
  }

  PageInstance instproc get_template_object {} {
    set id ${:page_template}
    if {![nsf::is object ::$id]} {
      ::xo::db::CrClass get_instance_from_db -item_id $id
    }
    return ::$id
  }

  PageInstance instproc get_form_constraints {{-trylocal false}} {
    # PageInstances have no form_constraints
    return ""
  }

  #FormPage instproc save args {
  #  :debug_msg [set :instance attributes]
  #  :log "IA=${:instance_attributes}"
  #  next
  #}

  FormPage instproc get_anon_instances {} {
    # maybe overloaded from WorkFlow
    :get_from_template anon_instances f
  }

  FormPage instproc get_form_constraints {{-trylocal false}} {
    #
    # This method os likely to be overloaded, maybe by xowf.
    #
    #:msg "is_form=[:is_form]"
    if {$trylocal && [:is_form]} {
      return [:property form_constraints]
    } else {
      #:msg "get_form_constraints returns '[:get_from_template form_constraints]'"
      return [:get_from_template form_constraints]
    }
  }

  FormPage instproc set_content {text} {
    if {$text eq ""} {
      set :text $text
    } else {
      next
    }
  }

  PageInstance ad_instproc get_from_template {var {default ""}} {
    Get a property from the parent object (template). The parent
    object might by either an ::xowiki::Form or an ::xowiki::FormPage

    @return either the property value or a default value
  } {
    set form_obj [:get_template_object]
    #:msg "get $var from template form_obj=$form_obj [$form_obj info class]"

    # The resulting page should be either a Form (PageTemplate) or
    # a FormPage (PageInstance)
    #
    #:msg "parent of self ${:name} is [$form_obj name] type [$form_obj info class]"
    #
    # If it is as well a PageInstance, we find the information in the
    # properties of this page. Note that we cannot distinguish here between
    # intrinsic (starting with _) and extension variables, since get_from
    # template does not know about the logic with "_" (just "property" does).
    #
    if {[$form_obj istype ::xowiki::PageInstance]} {
      #:msg "returning property $var from parent formpage $form_obj => '[$form_obj property $var $default]'"
      return [$form_obj property $var $default]
    }

    #
    # .... otherwise, it should be an instance variable ....
    #
    if {[$form_obj exists $var]} {
      #:msg "returning parent instvar [$form_obj set $var]"
      return [$form_obj set $var]
    }
    #
    # .... or, we try to resolve it against a local property.
    #
    # This case is currently needed in the workflow case, where
    # e.g. anon_instances is tried to be fetched from the first form,
    # which might not contain it, if e.g. the first form is a plain
    # wiki page.
    #
    #:msg "resolve local property $var=>[:exists_property $var]"
    if {[:istype ::xowiki::FormPage] && [:exists_property $var]} {
      #:msg "returning local property [:property $var]"
      return [:property $var]
    }
    #
    # if everything fails, return the default.
    #
    #:msg "returning the default <$default>, parent is of type [$form_obj info class]"
    return $default
  }

  PageInstance instproc render_content {} {
    set html [:get_html_from_content [:get_from_template text]]
    set html [:adp_subst $html]
    #
    # Transitional code, should be removed after the release of
    # OpenACS 5.10: In case we have a folder instances without the
    # "description" field set, and we use the new folder.form, and the
    # update script was not yet executed, folders might appear as
    # empty. In these cases, call child-resources manually.
    #
    if {$html eq "" && [:is_folder_page]} {
      ns_log warning "render_content: [:item_id] '${:name}' is a folder page without a content (deprecated)"
      set html [:include child-resources]
    }

    return "<div class='[${:page_template} css_class_name -margin_form false]'>[:substitute_markup $html]</div>"
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
    set __ia [dict merge [:template_vars $content] ${:instance_attributes}]

    foreach var [dict keys $__ia] {
      #:log "-- set $var [list $__ia($var)]"
      # TODO: just for the lookup, whether a field is a richt text field,
      # there should be a more efficient and easier way...
      if {[string match "richtext*" [:get_field_type $var text]]} {
        # ignore the text/html info from htmlarea
        set value [lindex [dict get $__ia $var] 0]
      } else {
        set value [dict get $__ia $var]
      }
      # the value might not be from the form attributes (e.g. title), don't clear it.
      if {$value eq "" && [info exists :$var]} continue
      set :$var [:get_field_label $var $value]
    }
    next
  }

  PageInstance instproc count_usages {
    {-package_id 0}
    {-parent_id:integer 0}
    {-publish_status ready}
  } {
    return [::xowiki::PageTemplate count_usages -package_id $package_id \
                -parent_id $parent_id -item_id ${:item_id} -publish_status $publish_status]
  }

  #
  # Methods of ::xowiki::Object
  #
  Object instproc render_content {} {
    if {[[self]::payload info methods content] ne ""} {
      set html [[self]::payload content]
      #:log render-adp=[:render_adp]
      if {[:render_adp]} {
        set html [:adp_subst $html]
        return [:substitute_markup $html]
      } else {
        #return "<pre>[string map {> &gt; < &lt;} ${:text}]</pre>"
        return $html
      }
    }
  }

  Object instproc initialize_loaded_object {} {
    :set_payload ${:text}
    next
  }

  Object instproc set_payload {cmd} {
    set payload [self]::payload
    if {[nsf::is object $payload]} {$payload destroy}
    ::xo::Context create $payload -requireNamespace \
        -actual_query [::xo::cc actual_query]
    $payload set package_id ${:package_id}
    ad_try {
      $payload contains $cmd
      $payload init
    } on error {errorMsg} {
      ad_log error "xowiki::Object set_payload: content $cmd lead to error: $errorMsg"
      ::xo::xotcl_object_cache flush ${:item_id}
    }
  }

  Object instproc get_payload {var {default ""}} {
    set payload [self]::payload
    if {![nsf::is object $payload]} {
      ::xo::Context create $payload -requireNamespace
    }
    expr {[$payload exists $var] ? [$payload set $var] : $default}
  }

  #
  # Methods of ::xowiki::Form
  #
  Form instproc footer {} {
    return [:include [list form-menu -form_item_id ${:item_id}]]
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
    if {$root ne ""} {
      :dom_disable_input_fields -with_submit $with_submit $root
      set form [lindex [$root selectNodes //form] 0]
      set marginForm [::xowiki::CSS class "margin-form"]
      if {$marginForm ne ""} {
        Form add_dom_attribute_value $form class $marginForm
      }
      return [$root asHTML]
    } else {
      ns_log notice "Form $form is apparently empty"
    }
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
    ::xowiki::Form requireFormCSS

    #
    # We assume that the richtext is stored as 2-element list with
    # mime-type.
    #
    #:log "-- text='${:text}'"
    if {[lindex ${:text} 0] ne ""} {
      set :do_substitutions 0
      set html ""; set mime ""
      lassign ${:text} html mime
      set content [:substitute_markup $html]
    } elseif {[lindex ${:form} 0] ne ""} {
      #
      # The method "disable_input_fields" consists essentially of
      #
      #     dom parse -simple $form doc
      #     ...
      #     return [$root asHTML]
      #
      #  Unfortunately, this causes that some tags unknown to tdom
      #  (like <adp:icon>) are converted to escaped tags (&lt; ...).
      #  This can be regarded as a bug. To avoid this problem, we
      #  substitute here the adp_tags in advance. This needs more
      #  investigation in other cases.... The potential harm in this
      #  cases here is very little, but probably, there are other
      #  cases as well where this might harm.
      #
      set content [[self class] disable_input_fields [template::adp_parse_tags [lindex ${:form} 0]]]
    } else {
      set content ""
    }
    return $content
  }

  Form instproc get_form_constraints args {
    # We define it as a method to ease overloading.
    return [:form_constraints]
  }

  FormPage instproc create_form_fields_from_names {
    {-lookup:switch}
    {-set_values:switch}
    {-form_constraints}
    field_names
  } {
    #
    # Create form-fields from field names. When "-lookup" is
    # specified, the code tries to reuseexisting form-field instead of
    # creating/recreating it.
    #
    # Since create_raw_form_field uses destroy_on_cleanup, we do not
    # have to care here about destroying the objects.
    #
    set form_fields {}
    foreach field_name $field_names {
      if {$lookup && [:form_field_exists $field_name]} {
        #:msg "... found form_field for $field_name"
        lappend form_fields [:lookup_form_field -name $field_name {}]
      } else {
        #:msg "create '$spec_name' with spec '$short_spec'"
        lappend form_fields [:create_raw_form_field \
                                 -name $field_name \
                                 -form_constraints $form_constraints \
                                ]
      }
    }
    if {$set_values} {
      :load_values_into_form_fields $form_fields
    }
    return $form_fields
  }

  Page ad_instproc create_form_fields_from_form_constraints {
    {-lookup:switch}
    form_constraints
  } {

     Create form-fields from form constraints. When "-lookup" is
     specified, the code reuses existing form-field instead of
     recreating it.

     Since create_raw_form_field uses destroy_on_cleanup, we do not
     have to care here about destroying the objects.

     @return potentially empty list of form-field objects
   } {
    set form_fields [list]
    foreach name_and_spec $form_constraints {
      regexp {^([^:]+):(.*)$} $name_and_spec _ spec_name short_spec
      if {[string match "@table*" $spec_name]
          || $spec_name in {@categories @cr_fields}
        } continue
      if {$lookup && [:form_field_exists $spec_name]} {
        #:msg "... found form_field for $spec_name"
        lappend form_fields [:lookup_form_field -name $spec_name {}]
      } else {
        #:msg "create '$spec_name' with spec '$short_spec'"
        lappend form_fields [:create_raw_form_field \
                                 -name $spec_name \
                                 -slot [:find_slot $spec_name] \
                                 -spec $short_spec \
                                 -form_constraints $form_constraints \
                                ]
      }
    }
    return $form_fields
  }

  Page instproc validate=form_constraints {form_constraints} {
    #
    # First check for invalid meta characters for security reasons.
    #
    #if {[regexp {[\[\]]} $form_constraints]} {
    #  :uplevel [list set errorMsg [_ xowiki.error-form_constraint-invalid_characters]]
    #  return 0
    #}
    #
    # Create from fields from all specs and report, if there are any errors
    #
    ad_try {
      :create_form_fields_from_form_constraints $form_constraints
    } on error {errorMsg} {
      ad_log error "error during form_constraints validator: $errorMsg"
      :uplevel [list set errorMsg $errorMsg]
      #:log "ERROR: invalid spec '$short_spec' for form field '$spec_name' -- $errorMsg"
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
    # to provide their own set of instance attributes.
    return [list]
  }

  Page instproc add_computed_instance_attributes {} {
    #
    # Provide a hook to add computed instances attributes e.g. from a
    # workflow. This method is used e.g. in form-usages for displaying
    # instance attributes in a sortable table or via csv.
    #
  }

  #
  # Methods of ::xowiki::FormPage
  #
  FormPage instproc initialize_loaded_object {} {
    #:msg "${:name} [:info class]"
    if {[info exists :page_template]} {
      set p [::xo::db::CrClass get_instance_from_db -item_id ${:page_template}]
      #
      # The Form might come from a different package type (e.g. a
      # workflow) make sure, the source package is available.
      #
      # Note that global pages (site_wide_pages) might not belong to
      # a package and have therefore an empty package_id.
      #
      set package_id [$p package_id]
      if {$package_id ne ""} {
        ::xo::Package require $package_id
      }
    }
    next
  }
  FormPage instproc initialize {} {
    # can be overloaded
  }

  FormPage instproc condition=in_state {query_context value} {
    # possible values can be or-ed together (e.g. initial|final)
    foreach v [split $value |] {
      #:msg "check [:state] eq $v"
      if {[:state] eq $v} {return 1}
    }
    return 0
  }

  FormPage ad_proc compute_filter_clauses {-unless -where} {

    Compute from "-unless" or "-where" specs the "tcl", "sql" and
    optional "hstore" query fragments.

    @return dict containing "init_vars", "uc" (unless clauses)
            and "wc" (where clauses)
  } {

    set init_vars [list]
    set uc {tcl false h "" vars "" sql ""}
    if {[info exists unless]} {
      set uc [dict merge $uc [:filter_expression $unless ||]]
      set init_vars [list {*}$init_vars {*}[dict get $uc vars]]
    }
    set wc {tcl true h "" vars "" sql ""}
    if {[info exists where]} {
      set wc [dict merge $wc [:filter_expression $where &&]]
      set init_vars [list {*}$init_vars {*}[dict get $wc vars]]
    }
    return [list init_vars $init_vars uc $uc wc $wc]
  }

  FormPage proc sql_value {input} {
    #
    # Transform wild-card * into SQL wild-card.
    #
    return [string map {* %} $input]
  }

  FormPage proc filter_expression {
                                   {-sql true}
                                   input_expr
                                   logical_op
                                 } {
    #ns_log notice "filter_expression '$input_expr' $logical_op"

    #
    # example for unless: wf_current_state = closed|accepted || x = 1
    #

    array set tcl_op {= eq < < > > >= >= <= <=}
    array set sql_op {= =  < < > > >= >= <= <=}
    array set op_map {
      contains,sql {$lhs_var like '%$sql_rhs%'}
      contains,tcl {{$rhs} in $lhs_var}
      matches,sql {$lhs_var like '$sql_rhs'}
      matches,tcl {[string match "$rhs" $lhs_var]}
    }

    set tcl_clause [list]
    set h_clause [list]
    set vars [list]
    set sql_clause [list]
    foreach clause [split [string map [list $logical_op \x00] $input_expr] \x00] {
      if {[regexp {^(.*[^<>])\s*([=<>]|<=|>=|contains|matches)\s*([^=]?.*)$} $clause _ lhs op rhs_expr]} {
        set lhs [string trim $lhs]
        set rhs_expr [string trim $rhs_expr]
        if {[string index $lhs 0] eq "_"} {
          #
          # Comparison with field names starting with "_"
          #
          set lhs_var [string range $lhs 1 end]
          set rhs [split $rhs_expr |]
          set sql_rhs [:sql_value $rhs]
          #:msg "check op '$op' in SQL [info exists op_map($op,sql)]"
          if {[info exists op_map($op,sql)]} {
            lappend sql_clause [subst -nocommands $op_map($op,sql)]
            if {[info exists :db_slot($lhs_var)]} {
              set lhs_var "\[set :$lhs_var\]"
              lappend tcl_clause [subst -nocommands $op_map($op,tcl)]
            } else {
              :msg "ignoring unknown variable '$lhs_var' in expression (have '[lsort [array names :db_slot]]')"
            }
          } elseif {[llength $rhs]>1} {
            lappend sql_clause "$lhs_var in ([ns_dbquotelist $rhs])"
            # the following statement is only needed, when we rely on tcl-only
            lappend tcl_clause "\[lsearch -exact {$rhs} \[:property $lhs\]\] > -1"
          } else {
            lappend sql_clause "$lhs_var $sql_op($op) '$rhs'"
            # the following statement is only needed, when we rely on tcl-only
            lappend tcl_clause "\[:property $lhs\] $tcl_op($op) {$rhs}"
          }
        } else {
          #
          # Field names referring to instance attributes.
          #
          set hleft [::xowiki::hstore::double_quote $lhs]
          lappend vars $lhs ""
          if {$op eq "contains"} {
            #make approximate query
            set lhs_var instance_attributes
            set sql_rhs $rhs_expr
            lappend sql_clause [subst -nocommands $op_map($op,sql)]
          }
          set lhs_var "\[dict get \$__ia $lhs\]"
          set tcl_rhs_clauses {}
          foreach rhs [split $rhs_expr |] {
            set sql_rhs [:sql_value $rhs]
            if {[info exists op_map($op,tcl)]} {
              lappend tcl_rhs_clauses [subst -nocommands $op_map($op,tcl)]
            } else {
              lappend tcl_rhs_clauses "$lhs_var $tcl_op($op) {$rhs}"
            }
            if {$op eq "="} {
              # TODO: think about a solution for other operators with
              # hstore maybe: extracting it by a query via hstore and
              # compare in plain SQL
              lappend h_clause "$hleft=>[::xowiki::hstore::double_quote $rhs]"
            }
          }
          lappend tcl_clause ([join $tcl_rhs_clauses ||])
        }
      } else {
        :msg "ignoring $clause"
      }
    }
    if {[llength $tcl_clause] == 0} {
      set tcl_clause [list true]
    }
    #:msg sql=$sql_clause,tcl=$tcl_clause
    set result [list \
                    tcl [join $tcl_clause $logical_op] \
                    h [join $h_clause ,] \
                    vars $vars \
                    sql $sql_clause]
    #:msg "filter_expression -sql $sql inp '$input_expr' log '$logical_op' -> $result"

    return $result
  }

  FormPage proc get_form_entries {
                                  -base_item_ids:required
                                  -package_id:required
                                  -form_fields:required
                                  {-publish_status ready}
                                  {-parent_id "*"}
                                  {-extra_where_clause ""}
                                  {-h_where {tcl true h "" vars "" sql ""}}
                                  {-h_unless {tcl true h "" vars "" sql ""}}
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
    # packages. Furthermore, a list of package_ids can be given.
    #
    # "-always_queried_attributes *" means to obtain enough attributes
    # to allow a save operations etc. on the instances.
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
    #:msg sql_atts=$sql_atts

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
    array set uc $h_unless
    set use_hstore [expr {[::xo::dc has_hstore] &&
                          [::$package_id get_parameter use_hstore 0]
                        }]
    #
    # Deactivating hstore optimization for now, must be further
    # compeleted and debugged before activating it again.
    #
    if {$wc(h) ne "" || $uc(h) ne ""} {
      ns_log notice "hstore available $use_hstore, but deactivating anyway for now (wc $wc(h) uc $uc(h) )"
    }

    set use_hstore 0
    if {$use_hstore} {
      if {$wc(h) ne ""} {
        set filter_clause " and '$wc(h)' <@ hkey"
      }
      if {$uc(h) ne ""} {
        set filter_clause " and not '$uc(h)' <@ hkey"
      }
    }
    if {$wc(sql) ne ""} {
      #:log "... wc SQL '$wc(sql)'"
      foreach filter $wc(sql) {
        append filter_clause " and $filter"
      }
    }
    if {$uc(sql) ne ""} {
      #:log "... uc SQL '$uc(sql)'"
      foreach filter $uc(sql) {
        append filter_clause " and not $filter"
      }
    }
    #:log filter_clause=$filter_clause

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
      set package_clause "and package_id in ([ns_dbquotelist $from_package_ids])"
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
                 -where " page_template in ([ns_dbquotelist $base_item_ids]) \
            $publish_status_clause $filter_clause $package_clause $parent_clause \
            $extra_where_clause" \
                 -orderby $orderby \
                 -limit $limit -offset $offset]
    #ns_log notice "get_form_entries:\n[string map [list :parent_id $parent_id :package_id $package_id] $sql]"

    #
    # When we query all attributes, we return objects named after the
    # item_id (like for single fetches)
    #
    set named_objects [expr {$always_queried_attributes eq "*"}]
    set items [::xowiki::FormPage instantiate_objects -sql $sql \
                   -named_objects $named_objects -object_named_after "item_id" \
                   -object_class ::xowiki::FormPage -initialize $initialize]

    #:log "$use_hstore wc tcl $wc(tcl) uc tcl $uc(tcl)"
    if {!$use_hstore && ($wc(tcl) != "true" || $uc(tcl) != "true")} {

      set init_vars $wc(vars)
      foreach p [$items children] {
        $p set __ia [dict merge $init_vars [$p instance_attributes]]

        if {$wc(tcl) != "true"} {
          if {![nsf::directdispatch $p -frame object ::expr $wc(tcl)]} {
            #:log "WC check '$wc(tcl)' [$p name] => where DELETE"
            $items delete $p
            continue
          }
        }
        if {$uc(tcl) != "true"} {
          if {[nsf::directdispatch $p -frame object ::expr $uc(tcl)]} {
            #:log "UC check '$uc(tcl)' on [$p name] => unless DELETE"
            $items delete $p
          }
        }
      }
    }
    return $items
  }

  FormPage proc get_folder_children {
                                     -folder_id:required
                                     {-publish_status ready}
                                     {-object_types {::xowiki::Page ::xowiki::Form ::xowiki::FormPage}}
                                     {-extra_where_clause true}
                                     {-initialize true}
                                   } {
    set publish_status_clause [::xowiki::Includelet publish_status_clause $publish_status]
    set result [::xo::OrderedComposite new -destroy_on_cleanup]

    foreach object_type $object_types {
      set attributes [list revision_id creation_user title parent_id page_order \
                          "to_char(last_modified,'YYYY-MM-DD HH24:MI') as last_modified" ]
      set base_table [$object_type set table_name]i
      if {$object_type eq "::xowiki::FormPage"} {
        set attributes "bt.* $attributes"
      }
      set items [$object_type get_instances_from_db \
                     -folder_id $folder_id \
                     -with_subtypes false \
                     -select_attributes $attributes \
                     -where_clause "$extra_where_clause $publish_status_clause" \
                     -base_table $base_table \
                     -initialize $initialize]

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
      set page [::$package_id get_page_from_item_ref $item_ref]
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
                                  {-extra_where_clause "1=1"}
                                  {-include_child_folders none}
                                  {-initialize true}
                                } {

    set folder [::xo::db::CrClass get_instance_from_db -item_id $folder_id -revision_id 0]
    set package_id [$folder package_id]

    set publish_status_clause [::xowiki::Includelet publish_status_clause $publish_status]
    set result [::xo::OrderedComposite new -destroy_on_cleanup]
    $result set folder_ids ""

    set list_of_folders [list $folder_id]
    set inherit_folders [FormPage get_super_folders $package_id $folder_id]
    #:log inherit_folders=$inherit_folders

    foreach item_ref $inherit_folders {
      set folder [::xo::cc cache [list ::$package_id get_page_from_item_ref $item_ref]]
      if {$folder eq ""} {
        ad_log error "Could not resolve parameter folder page '$item_ref' of FormPage [self]."
      } else {
        lappend list_of_folders [$folder item_id]
      }
    }

    if {$include_child_folders eq "direct"} {
      #
      # Get all children of the current folder on the first level and
      # append it to the list_of_folders.
      #
      set folder_form [::$package_id instantiate_forms -forms en:folder.form]
      set child_folders [xo::dc list -prepare integer,integer get_child_folders {
        select item_id from xowiki_form_instance_item_index
        where parent_id = :folder_id
        and page_template = :folder_form
      }]
      foreach f $child_folders {
        ::xo::db::CrClass get_instance_from_db -item_id $f
      }
      lappend list_of_folders {*}$child_folders
    }

    $result set folder_ids $list_of_folders

    foreach folder_id $list_of_folders {
      foreach object_type $object_types {
        set attributes [list revision_id creation_user title parent_id page_order \
                            "to_char(last_modified,'YYYY-MM-DD HH24:MI') as last_modified" ]
        set base_table [$object_type set table_name]i
        if {$object_type eq "::xowiki::FormPage"} {
          set attributes "bt.* $attributes"
        }
        set items [$object_type get_instances_from_db \
                       -folder_id $folder_id \
                       -with_subtypes false \
                       -initialize $initialize \
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
    #
    # Try to get the parameter from the parameter_page provided as
    # property "ParameterPages".
    #
    set value [::${:package_id} get_parameter_from_parameter_page \
                   -parameter_page_name [:property ParameterPages] \
                   $attribute]
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
      return [info exists :$varname]
    }
    return [dict exists ${:instance_attributes} $name]
  }

  FormPage ad_instproc property {
    name
    {default ""}
  } {
    Retrieve a FormPage property.

    @param name property name. Names starting with _ refer to object's
                members, rather than instance attributes.
    @param default fallback value when property is not set.
  } {
    if {[regexp {^_([^_].*)$} $name _ varname]} {
      if {[info exists :$varname]} {
        return [set :$varname]
      }
    } elseif {[dict exists ${:instance_attributes} $name]} {
      return [dict get ${:instance_attributes} $name]
    }
    return $default
  }

  FormPage ad_instproc set_property {
    {-new 0}
    name
    value
  } {
    Stores a value as FormPage property

    @param new boolean flag telling if the property is new. Setting a
               value on a non-existing property without specifying
               this flag will result in an error.
    @param name property name. Names starting with _ indicate an
                object variable rather than a property stored in
                instance_attributes
    @param value property value

    @return value (eventually converted to a has-notation message key)
  } {
    if {[string match "_*" $name]} {
      set key [string range $name 1 end]

      if {!$new && ![info exists :$key]} {
        error "property '$name' ($key) does not exist. \
        you might use flag '-new 1' for set_property to create new properties"
      }
      set :$key $value

    } else {

      if {!$new && ![dict exists ${:instance_attributes} $name]} {
        error "property '$name' does not exist. \
        you might use flag '-new 1' for set_property to create new properties"
      }
      dict set :instance_attributes $name $value
    }
    return $value
  }

  FormPage ad_instproc get_property {
    -source
    -name:required
    {-default ""}
  } {
    Retrieves a FormPage property

    @param source page name to be resolved and used instead this
                  FormPage to fetch the property
  } {
    if {![info exists source]} {
      set page [self]
    } else {
      set page [:resolve_included_page_name $source]
    }
    return [$page property $name $default]
  }

  FormPage instproc lappend_property {name value} {
    #
    # lappend the specified value to the named property. If the
    # property does not exists, create a new one.
    #
    if {[:exists_property $name]} {
      :set_property $name [concat [:get_property -name $name] $value]
    } else {
      :set_property -new 1 $name $value
    }
  }

  FormPage instproc condition=is_true {query_context value} {
    #
    # This condition maybe called from the policy rules.
    # The passed value is a tuple of the form
    #     {property-name operator property-value}
    #
    lassign $value property_name op property_value
    if {![info exists property_value]} {
      return 0
    }

    #:log "$value => [:adp_subst $value]"
    array set wc [::xowiki::FormPage filter_expression [:adp_subst $value] &&]
    #:log "wc= [array get wc]"
    set __ia [dict merge $wc(vars) [:instance_attributes]]
    #:log "expr $wc(tcl) returns => [expr $wc(tcl)]"
    return [expr $wc(tcl)]
  }

  # If the folder has a property "langstring" assume that the
  # content is a dict containing multiple attributes in multiple
  # languages.
  #
  #    _title {en {This is the Title} de {Das ist der Titel}}
  #
  # This can be used by update_langstring_property to set arbitaries
  # properties to language-specific value. The follogwing command updates
  # the value of the "_title" property:
  #
  #    $page update_langstring_property _title $lang
  #
  # One should define a form-field for langstrings that convert
  # some user-friendly format into the intrep of the dict, which
  # can be efficiently processed.

  FormPage instproc langstring {attname lang {default ""}} {
    set result $default
    if {[:exists_property langstring]} {
      set d [:property langstring]
      if {[dict exists $d $attname $lang]} {
        set result [dict get $d $attname $lang]
      }
    }
    return $result
  }
  FormPage instproc update_langstring_property {attname lang} {
    :set_property $attname [:langstring $attname $lang [:property $attname]]
  }

  #
  # end property management
  #

  FormPage instproc set_publish_status {value} {
    if {$value ni {production ready}} {
      error "invalid value '$value'; use 'production' or 'ready'"
    }
    set :publish_status $value
  }

  FormPage instproc footer {} {
    if {[info exists :__no_form_page_footer]} {
      next
    } else {
      set is_form [:property is_form__ 0]
      if {[:is_form]} {
        return [:include [list form-menu -form_item_id ${:item_id} \
                              -buttons [list new answers [list form ${:page_template}]]]]
      } else {
        return [:include [list form-menu -form_item_id ${:page_template} -buttons form]]
      }
    }
  }


  FormPage instproc field_names_from_form {{-form ""}} {
    #
    # This method returns the form attributes (including _*).
    #
    set allvars [list {*}[[:info class] array names db_slot] \
                     {*}[::xo::db::CrClass set common_query_atts]]

    set template [:get_html_from_content [:get_from_template text]]
    #:msg template=$template

    #set field_names [list _name _title _description _creator _nls_language _page_order]
    set field_names [list]
    if {$form eq ""} {set form [:get_form]}
    if {$form eq ""} {
      foreach {var _} [:template_vars $template] {
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
      #ns_log notice "field_names_from_form: [:serialize]"
      dom parse -html -simple $form doc
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
    return [list text [namespace tail [:info class]] is_richtext false]
  }

  File instproc render_icon {} {
    return {text "<a title='file' class='file-icon'>&nbsp;</a>" is_richtext true}
  }

  FormPage instproc render_icon {} {
    set page_template ${:page_template}
    if {[$page_template istype ::xowiki::FormPage]} {
      return [list text [$page_template property icon_markup] is_richtext true]
    }
    switch [$page_template name] {
      en:folder.form {
        return {text "<a title='folder' class='folder-open-icon'>&nbsp;</a>" is_richtext true}
      }
      en:link.form {
        set link_type [:get_property_from_link_page link_type "unresolved"]
        if {$link_type eq "unresolved"} {
          return {text "<a title='broken link' class='broken-link-icon'>&nbsp;</a>" is_richtext true}
        } else {
          return {text "<a title='link' class='link-icon'>&nbsp;</a>" is_richtext true}
        }
      }
      default {
        return [list text [$page_template title] is_richtext false]
      }
    }
  }

  Page instproc pretty_name {} {
    return ${:name}
  }

  FormPage instproc pretty_name {} {
    set anon_instances [:get_from_template anon_instances f]
    if {$anon_instances} {
      return ${:title}
    }
    return ${:name}
  }

  File instproc pretty_name {} {
    set name ${:name}
    regsub {^file:} $name "" name
    return $name
  }

  FormPage instproc include_header_info {{-prefix ""} {-js ""} {-css ""}} {
    if {$css eq ""} {set css [:get_from_template ${prefix}_css]}
    if {$js eq ""}  {set js [:get_from_template ${prefix}_js]}
    foreach line [split $js \n] {
      set line [string trim $line]
      if {$line ne ""} {
        ::xo::Page requireJS $line
      }
    }
    foreach line [split $css \n] {
      set line [string trim $line]
      if {$line eq ""} continue
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
    #
    # Produce an HTML rendering from the FormPage.
    #
    #set package_id ${:package_id}
    :include_header_info -prefix form_view
    if {[::xo::cc mobile]} {
      :include_header_info -prefix mobile
    }
    set text [:get_from_template text]
    if {$text ne ""} {
      catch {set text [lindex $text 0]}
    }
    if {$text ne ""} {
      #:log "we have a template text='$text'"
      #
      # We have a template, this is the first preference.
      #
      set HTML [next]
    } else {
      #:log "we have a form '[:get_form]'"
      #
      # Fall back to the form, fill it out and compute HTML from this.
      #
      set form [:get_form]
      if {$form eq ""} {
        return ""
      }

      lassign [:field_names_from_form -form $form] form_vars field_names
      set :__field_in_form ""
      if {$form_vars} {
        foreach v $field_names {
          dict set :__field_in_form $v 1
        }
      }
      set form_fields [:create_form_fields $field_names]
      foreach n $field_names f $form_fields {
        dict set :__form_fields $n $f
      }

      :load_values_into_form_fields $form_fields

      # deactivate form-fields and do some final sanity checks
      foreach f $form_fields {$f set_disabled 1}
      :form_fields_sanity_check $form_fields
      :post_process_form_fields $form_fields

      set form [:regsub_eval  \
                    [template::adp_variable_regexp] $form \
                    {:form_field_as_html -mode display "\\\1" "\2" $form_fields}]

      # we parse the form just for the margin-form.... maybe regsub?
      dom parse -html -simple $form :doc
      ${:doc} documentElement :root
      set form_node [lindex [${:root} selectNodes //form] 0]

      Form add_dom_attribute_value $form_node role form
      Form add_dom_attribute_value $form_node class [${:page_template} css_class_name]
      # The following two commands are for non-generated form contents
      :set_form_data $form_fields
      Form dom_disable_input_fields ${:root}
      # Return finally the result
      set HTML [${:root} asHTML]
    }

    return $HTML
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
        # The form field exists already, we just fill in the actual
        # value (needed e.g. in weblogs, when the same form field is
        # used for multiple page instances in a single request)
        #
        set value [$f value [:property $varname]]
      } else {
        #
        # create a form-field from scratch
        #
        set value [:property $varname]
        set f [:create_form_field -cr_field_spec $cr_field_spec -field_spec $field_spec $varname]
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
    set field_spec [:get_short_spec @fields]
    set cr_field_spec [:get_short_spec @cr_fields]
    # Iterate over the variables for substitution
    set content [:regsub_eval -noquote true \
                     [template::adp_variable_regexp] " $content" \
                     {:get_value -field_spec $field_spec -cr_field_spec $cr_field_spec "\\\1" "\2"}]
    return [string range $content 1 end]
  }

  FormPage instproc group_require {} {
    #
    # Create a group if necessary associated to the current form
    # page. Since the group_names are global, the group name contains
    # the parent_id of the FormPage.
    #
    set group_name "fpg-${:parent_id}-${:name}"
    set group_id [group::get_id -group_name $group_name]
    if {$group_id eq ""} {
      # group::new does not flush the cache - sigh!  Therefore, we have
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
        #:msg "we have to add $m"
        group::add_member -group_id $group_id -user_id $m \
            -rel_type $rel_type -member_state $member_state
      }
    }
    foreach m $old_members {
      if {$m ni $members} {
        #:msg "we have to remove $m"
        group::remove_member -group_id $group_id -user_id $m
      }
    }
  }


  Page instproc is_new_entry {old_name} {
    return [expr {${:publish_status} eq "production" && $old_name eq ${:revision_id}}]
  }

  Page instproc unset_temporary_instance_variables {} {
    #
    # Don't marshall/save/cache the following vars:
    #
    # array unset :__ia
    unset -nocomplain :__form_fields :__field_in_form  :__field_needed
  }

  Page instproc map_categories {category_ids} {
    #
    # Could be optimized, if we do not want to have categories (form
    # constraints?)
    #
    #:log "--category::map_object -remove_old -object_id ${:item_id} <$category_ids>"
    category::map_object -remove_old -object_id ${:item_id} $category_ids
  }

  Page instproc rename {-old_name -new_name} {
    ${:package_id} flush_name_cache -name $old_name -parent_id ${:parent_id}
    next
    :log "----- rename <$old_name> to <$new_name>"
    #ns_log notice [:serialize]
  }

  #
  # The method save_data is called typically via www-callable methods
  # and has some similarity to "new_data" and "edit_data" in
  # "ad_forms". It performs some updates in an instance (e.g. caused
  # by categories), saves the data and calls finally the notification
  # procs.
  #
  Page instproc save_data {{-use_given_publish_date:boolean false} old_name category_ids} {
    #:log "-- [self args]"
    :unset_temporary_instance_variables
    set package_id ${:package_id}

    ::xo::dc transaction {
      #
      # If the newly created item was in production mode, but ordinary entries
      # are not, change on the first save the status to ready
      #
      #ns_log notice "----- save_data: old_name $old_name, is_new_entry [:is_new_entry $old_name] name <${:name}>"
      if {[:is_new_entry $old_name]} {
        if {![::$package_id get_parameter production_mode 0]} {
          set :publish_status "ready"
        }
      }
      :map_categories $category_ids

      #
      # Handle now further database operations that should be saved in
      # a transaction. Examples are calendar-items defined in a
      # FormPage, which should show up also in the calendar.
      #
      # Probably, categories should also be moved into the
      # transaction queue.
      #
      set queue ::__xowiki__transaction_queue(${:item_id})
      if {[info exists $queue]} {
        foreach cmd [set $queue] {
          #ns_log notice ".... executing transaction command: $cmd"
          {*}$cmd
        }
      }

      :save -use_given_publish_date $use_given_publish_date
      if {$old_name ne ${:name}} {
        :rename -old_name $old_name -new_name ${:name}
      }
      :notification_notify
    }
    return ${:item_id}
  }

}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
