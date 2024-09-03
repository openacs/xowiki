::xo::library doc {

    Includelet for a graph displaying wiki references.

    @author Gustaf Neumann
}
::xo::library require includelet-procs

if {[info commands ::try] eq ""} {
    package require try
}

namespace eval ::xowiki::includelet {

    ::xowiki::IncludeletClass create references-graph \
        -superclass ::xowiki::Includelet \
        -parameter {
            {__decoration none}
            {parameter_declaration {
                {-folder .}
                {-page ""}
                {-link_type link}
                {-rankdir LR}
                {-fontsize 12}
            }}
        } -ad_doc {

            Include a graph of the (partial) link structure in a wiki,
            starting either with a page or a folder. When a page is
            provided, the local link structure of this page is
            visualized (including incoming and outgoing links of the
            page; e.g. -page "." for the current page).
            Alternatively, the content of a folder can be shown.

            @param page starting page for a partial link graph, provided as item ref
            @param folder starting page for showing all children of a folder (default .)
            @param rankdir possible values LR, TB, BT, or RL
            @param fontsize fontsize for graphviz (default 12)
        }


    references-graph instproc render {} {
        :get_parameters
        if {$page ne ""} {
            set page_info [$package_id item_ref \
                               -default_lang en \
                               -parent_id [${:__including_page} item_id] \
                               $folder]
            set item_id [dict get $page_info item_id]
            if {$item_id eq "0"} {
                error "cannot locate page $page"
            }
            set incoming [xo::dc list _ [subst {
                select distinct page from xowiki_references
                where reference = :item_id
                and link_type = :link_type
            }]]
            set items [lsort -unique [list $item_id {*}$incoming]]
            #ns_log notice "=== PAGE item_id $item_id incoming $incoming items $items"

        } else {
            set folder_info [$package_id item_ref \
                                 -default_lang en \
                                 -parent_id [${:__including_page} item_id] \
                                 $folder]
            set parent_id [dict get $folder_info item_id]
            if {$parent_id eq "0"} {
                error "cannot locate folder $folder"
            }
            set parent_object [::xo::db::CrClass get_instance_from_db -item_id $parent_id]
            if {![$parent_object is_folder_page]} {
                ns_log notice "get parent_id from parent"
                set parent_id [$parent_object parent_id]
            }
            #
            # Get all pages (item_ids) under parent_id relevant for the
            # link graph. In case, there are references to pages outside
            # this set, these pages are treated as "extern"
            #
            #ns_log notice "folder $folder, parent_id $parent_id"
            set items [xo::dc list _ {
                select item_id from cr_items where parent_id = :parent_id}]
            if {[llength $items] == 0} {
                return "No pages under $folder could be found"
            }
        }
        #
        # Get all references outgoing from these item_ids.
        #
        set references [xo::dc list _ [subst {
            select distinct reference from xowiki_references
            where page in ([ns_dbquotelist $items])
            and link_type = :link_type
        }]]
        set extern [lmap ref $references {if {$ref in $items} continue; set ref}]
        set all [lsort -unique [concat $items $extern]]

        #
        # Get all unresolved outgoing references from these item_ids.
        #
        set unresolved_references [xo::dc list_of_lists _ [subst {
            select page, name, parent_id from xowiki_unresolved_references
            where page in ([ns_dbquotelist $items])
            and link_type = :link_type
        }]]

        #ns_log notice "items [lsort $items]"
        #ns_log notice "extern [lsort $extern]"
        #ns_log notice "all [lsort $all]"
        #ns_log notice "unresolved [lsort $unresolved_references]"

        foreach tuple [xo::dc list_of_lists _ [subst {
            select ci.item_id, ci.name, ci.parent_id, cr.title, o.package_id
            from cr_items ci, cr_revisions cr, acs_objects o
            where ci.latest_revision = cr.revision_id
            and cr.item_id in ([ns_dbquotelist $all])
            and cr.item_id = o.object_id
        }]] {
            lassign $tuple item_id name parent_id title package_id
            dict set item_info $item_id name $name
            #ns_log notice "dict set item_info $item_id name $name"
            dict set item_info $item_id title $title
            dict set item_info $item_id package_id $package_id
            dict set item_info $item_id parent_id $parent_id
        }

        foreach i $all {
            if {[dict get $item_info $i parent_id] ne $parent_id} {
                dict set item_info $i extern 1
                ns_log notice "dict set item_info $i extern 1"
            }
        }

        set edges {}
        set nodes {}

        foreach pair [xo::dc list_of_lists _ [subst {
            select reference, page from xowiki_references
            where page in ([ns_dbquotelist $items])
            and link_type = :link_type
        }]] {
            lassign $pair reference page
            set key havelink($page,$reference)
            if {![info exists $key]} {
                set from       [dict get $item_info $page name]
                set from_label [dict get $item_info $page name]
                set to         [dict get $item_info $reference name]
                set to_label   [dict get $item_info $reference name]

                #set to_label   [dict get $item_info $reference title]
                #set from_label [dict get $item_info $page title]
                if {[dict exists $item_info $reference extern]} {
                    #
                    # We have an "external" reference, i.e. a
                    # reference to some other wiki page, which is not
                    # in the set under the provided parent_id.
                    #
                    ns_log notice "EXTERN reference from $page $from to $reference $to"

                    #
                    # Maybe we have to initialize a different package as well
                    #
                    set reference_package_id [dict get $item_info $reference package_id]
                    if {$reference_package_id ne $package_id} {
                        ::xo::Package initialize \
                            -package_id $reference_package_id \
                            -init_url false -keep_cc true
                    }
                    set targetObj [::xo::db::CrClass get_instance_from_db -item_id $reference]
                    set to_label [$targetObj pretty_link]
                    set shape box
                } else {
                    set targetObj [::xo::db::CrClass get_instance_from_db -item_id $reference]
                    set shape ellipse
                }
                set pageObj [::xo::db::CrClass get_instance_from_db -item_id $page]
                set pageUrl [$pageObj pretty_link]
                set referenceUrl [$targetObj pretty_link]
                append nodes [subst {"n$page" \[label="$from_label", fontsize=$fontsize, URL=\"$pageUrl\" \] \n}]
                append nodes [subst {"n$reference" \[label="$to_label", fontsize=$fontsize, URL=\"$referenceUrl\", shape=$shape\] \n}]
                append edges [subst {"n$page" -> "n$reference"\n}]
                set $key 1
            }
        }
        set nr_unresolved 0
        foreach unresolved_pair $unresolved_references {
            lassign $unresolved_pair page name parent_id
            set key _unsresolved_nodes($name,parent_id)
            if {![info exists $key]} {
                set $key u[incr nr_unresolved]
            }
            append nodes [subst {"[set $key]" \[label="$name", fontsize=$fontsize, shape=diamond, fontcolor=red, color=red\] \n}]
            append edges [subst {"n$page" -> "[set $key]"\n}]
        }
        set graph [subst {
            digraph D {
                rankdir=$rankdir; outputMode=edgesfirst;
                $nodes
                $edges
            }}]
        set css {
            div.xowiki-content .content-with-folders {
                float: left; width: 80%;
            }
            /*svg g a:link {text-decoration: none;}*/
            /*div.inner svg {width: 100%; height: 100%; margin: 0 auto;}*/
            svg g polygon {fill: transparent;}
            svg g g ellipse {fill: #eeeef4;}
            svg g g polygon {fill: #f4f4e4;}
        }

        #ns_log notice $graph
        set HTMLgraph [util::inline_svg_from_dot -css $css $graph]
        return "<div class='[namespace tail [self class]]'>$HTMLgraph</div>"
    }
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
