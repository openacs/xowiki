::xo::library doc {
    XoWiki - category specific code

    @creation-date 2006-10-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {
  #
  # Commonly used code for categories
  # 
  Class create Category
  Category proc get_mapped_trees {
                  -object_id
                 {-locale ""} 
                 {-names ""} 
                 {-output {tree_id tree_name subtree_category_id assign_single_p require_category_p}} 
               } {
    # Return matched category trees matching the specified names (or all)

    # provide compatibility with earlier versions of categories
    set have_locale [expr {[lsearch [info args category_tree::get_mapped_trees] locale] > -1}]
    set mapped_trees [expr {$have_locale ?
                            [category_tree::get_mapped_trees $object_id $locale] :
                            [category_tree::get_mapped_trees $object_id]}]
    set trees [list]
    foreach tree $mapped_trees {
      foreach {tree_id my_tree_name ...} $tree {break}

      # "names" is a list of category names
      if {$names ne ""} {
        # Check, if the current name matches any of the given
        # names. If the name contains wild-cards, perform a string
        # match, otherwise a string equal.
        set match 0
        foreach n $names {
          if {[string first * $n] > -1} {
            if {![string match $n $my_tree_name]} {
              set match 1
              break
            }
          } elseif {$n eq $my_tree_name} {
            set match 1
            break
          }
        }
        if {!$match} continue
      }
      # Get the values from info in "tree" into separate variables given by output.
      # Note, that the order matters!
      foreach $output $tree break
      set l [list]
      foreach __var $output {lappend l [set $__var]}
      lappend trees $l
    }
    return $trees
  }

  Category proc get_category_infos {{-all false} {-subtree_id ""} {-locale ""} -tree_id} {
    #
    # provide a common interface to older versions of categories
    #
    # provide compatibility with earlier versions of categories
    set have_locale [expr {[lsearch [info args category_tree::get_tree] locale] > -1}]
    set all_arg [expr {$all ? "-all" : ""}]
    return [expr {$have_locale ?
                  [eval category_tree::get_tree $all_arg -subtree_id [list $subtree_id] $tree_id $locale] :
                  [eval category_tree::get_tree $all_arg -subtree_id [list $subtree_id] $tree_id]}]
  }
}

::xo::library source_dependent 

