::xowiki::Package initialize -ad_doc {
  This is the admin page for the package.  It displays all entries
  provides links to create, edit and delete these

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$

  @param object_type show objects of this class and its subclasses
} -parameter {
  {-object_type:token,optional}
  {-orderby:token,optional "last_modified,desc"}
}

set context [list index]

# if object_type is specified, only list entries of this type;
# otherwise show types and subtypes of $supertype
if {![info exists object_type]} {
  set per_type 0
  set supertype ::xowiki::Page
  set object_types [$supertype object_types]
  set pretty_plural [$supertype set pretty_plural]
  set page_title [_ xowiki.listing_title_all]
  set with_subtypes true
  set object_type $supertype
  set with_children true
} else {
  set per_type 1
  set object_types [list $object_type]
  set pretty_plural [$object_type set pretty_plural]
  set page_title [_ xowiki.listing_title]
  set with_subtypes false
  set with_children true
}

set CSSToolkit [::xowiki::Package preferredCSSToolkit]
if {$CSSToolkit eq "bootstrap"} {
  template::head::add_css -href urn:ad:css:bootstrap3
}
template::head::add_css \
    -href urn:ad:css:xowiki-$CSSToolkit

# if you would like to have a confirmation popup before deleting, uncomment the following lines
# template::add_confirm_handler -CSSclass "list delete-item-button" \
#   -message [_ xowiki.delete_confirm]

set return_url [expr {$per_type ? [export_vars -base [::$package_id url] object_type] :
                      [::$package_id url]}]

set category_url [export_vars -base [::$package_id package_url] { {manage-categories 1} {object_id $package_id}}]


set actions [subst {
  Action new -label "[lang::message::lookup {} categories.Categories Categories]" \
      -url $category_url
}]
foreach type $object_types {
  set link [::$package_id make_link -with_entities 0 \
                $package_id edit-new {object_type $type} return_url autoname]
  if {$link eq ""} continue
  append actions [subst {
    Action new \
        -label "[_ xotcl-core.add [list type [$type pretty_name]]]" \
        -url "$link" \
        -tooltip  "[_ xotcl-core.add_long [list type [$type pretty_name]]]"
  }]
}

set ::individual_permissions [expr {[::$package_id set policy] eq "::xowiki::policy3"}]
set ::with_publish_status 1

TableWidget create t1 -volatile \
    -actions $actions \
    -columns {
      BulkAction objects -id name -actions {
        Action new -label [_ xowiki.export] -tooltip [_ xowiki.export] -url export
        Action new -label [_ xowiki.delete] -tooltip [_ xowiki.delete] -url bulk-delete
      }
      AnchorField edit -CSSclass edit-item-button -label "" -html {style "padding: 0px;"}
      if {$::individual_permissions} {
        ImageAnchorField create permissions -src /resources/xowiki/permissions.png -width 16 \
            -height 16 -border 0 -title "Manage Individual Permssions for this Item" \
            -alt permsissions -label "" -html {style "padding: 2px;"}
      }
      if {$::with_publish_status} {
        ImageAnchorField create publish_status -orderby publish_status.src -src "" \
            -width 8 -height 8 -title "Toggle Publish Status" \
            -alt "publish status" -label [_ xowiki.publish_status] -html {style "padding: 2px;text-align: center;"}
      }
      Field create syndicated -label "RSS" -html {style "padding: 2px; text-align: center;"}
      AnchorField create page_order -label [_ xowiki.Page-page_order] -orderby page_order -html {style "padding: 2px;"}
      AnchorField create name -label [_ xowiki.Page-name] -orderby name -html {style "padding: 2px;"}
      AnchorField create title -label [_ xowiki.Page-title] -orderby title
      Field create object_type -label [_ xowiki.page_type] -orderby object_type -html {style "padding: 2px;"}
      Field create size -label [_ xowiki.Size] -orderby size -html {align right style "padding: 2px;"}
      Field create last_modified -label [_ xowiki.Page-last_modified] -orderby last_modified
      Field create mod_user -label [_ xowiki.By_user] -orderby mod_user
      AnchorField create delete -CSSclass delete-item-button -label ""
    }
#    -renderer BootstrapTableRenderer



lassign [split $orderby ,] att order
t1 orderby -order [expr {$order eq "asc" ? "increasing" : "decreasing"}] $att

# -page_size 10
# -page_number 1

# for content_length, we need cr_revision and cannot use the base table
set attributes [list revision_id content_length creation_user title page_order parent_id \
                    "to_char(last_modified,'YYYY-MM-DD HH24:MI:SS') as last_modified" ]

set folder_id [::$package_id folder_id]
foreach i [xo::dc list get_syndicated {
  select s.object_id from syndication s, cr_items ci
  where s.object_id = ci.live_revision and ci.parent_id = :folder_id
}] { set syndicated($i) 1 }

xo::dc foreach instance_select \
    [$object_type instance_select_query \
         -folder_id $folder_id \
         -with_subtypes $with_subtypes \
         -from_clause ", xowiki_page p" \
         -where_clause "p.page_id = bt.revision_id" \
         -with_children $with_children \
         -select_attributes $attributes \
         -orderby ci.name \
        ] {
          if {[info commands ::$package_id] eq ""} {
            # Safety belt for cases, where the instance_select_query
            # brings in instances belonging to other packages.
            ns_log notice "admin/list: have to initialize package $package_id"
            ::xo::Package initialize -package_id $package_id -keep_cc true
          }
          set page_link [::$package_id pretty_link -parent_id $parent_id $name]
          set edit_link [::$package_id pretty_link -parent_id $parent_id \
                             -query [export_vars {{m edit} return_url}] \
                             $name]
          set name [::$package_id external_name -parent_id $parent_id $name]

          ::template::t1 add \
              -name $name \
              -title $title \
              -object_type [string map [list "::xowiki::" ""] $object_type] \
              -name.href $page_link \
              -last_modified $last_modified \
              -syndicated [info exists syndicated($revision_id)] \
              -size [expr {$content_length ne "" ? $content_length : 0}]  \
              -edit "" \
              -edit.href $edit_link \
              -edit.title #xowiki.edit# \
              -mod_user [::xo::get_user_name $creation_user] \
              -delete "" \
              -delete.href [export_vars -base [::$package_id package_url] {{delete 1} item_id name return_url}] \
              -delete.title #xowiki.delete#

          if {$::individual_permissions} {
            [::template::t1 last_child] set permissions.href \
                [export_vars -base permissions {item_id return_url}]
          }
          if {$::with_publish_status} {
            # TODO: this should get some architectural support
            if {$publish_status eq "ready"} {
              set image active.png
              set state "production"
            } else {
              set image inactive.png
              set state "ready"
            }
            [::template::t1 last_child] set publish_status.src /resources/xowiki/$image
            [::template::t1 last_child] set publish_status.href \
                [export_vars -base [::$package_id package_url]admin/set-publish-state \
                     {state revision_id return_url}]
          }
          [::template::t1 last_child] set page_order $page_order
        }


#ns_log notice "t1 renderer [t1 renderer] [t1 procsearch render]"
set t1 [t1 asHTML]
# db_foreach clobbers title, so re-establish it
set title $page_title

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
