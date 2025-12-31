::xo::library doc {
  XoWiki - package specific methods (deprecated)

  @creation-date 2006-10-10
  @author Gustaf Neumann
  @cvs-id $Id$
}

::xo::library require package-procs

namespace eval ::xowiki {

  #
  # import for prototype pages
  #

  Package instproc -deprecated import-prototype-page {args} {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-import-prototype-page {*}$args
  }

  ###############################################################
  #
  # user callable methods on package level
  #

  Package ad_instproc -deprecated refresh-login {args} {
  } {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-refresh-login {*}$args
  }

  #
  # reindex (for site wide search)
  #

  Package ad_instproc -deprecated reindex {args} {
  } {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-reindex {*}$args
  }
  #
  # change-page-order (normally called via ajax POSTs)
  #
  Package ad_instproc -deprecated change-page-order {args} {
  } {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-change-page-order {*}$args
  }


  #
  # RSS 2.0 support
  #
  Package ad_instproc -deprecated rss {args} {
  } {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-rss {*}$args
  }

  #
  # Google sitemap support
  #

  Package ad_instproc -deprecated google-sitemap {args} {

  } {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-google-sitemap {*}$args
  }

  Package ad_proc -deprecated google-sitemapindex {args} {

  } {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-google-sitemapindex {*}$args
  }

  Package instproc -deprecated google-sitemapindex {args} {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-google-sitemapindex {*}$args
  }

  #
  # Create new pages
  #

  Package instproc -deprecated edit-new {args} {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-edit-new {*}$args
  }

  #
  # manage categories
  #

  Package instproc -deprecated manage-categories {args} {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-manage-categories {*}$args
  }

  #
  # edit a single category tree
  #

  Package instproc -deprecated edit-category-tree {args} {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-edit-category-tree {*}$args
  }

  #
  # Package import
  #

  Package instproc -deprecated delete {args} {
    ad_log Warning "* Deprecated proc (Fix me!)"
    :www-delete {*}$args
  }
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
