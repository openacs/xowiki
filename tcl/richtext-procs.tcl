::xo::library doc {

  Richtext editors integrations

  Here we integrate various richtext editors as XoWiki formfields.

}

::xo::library require form-field-procs

namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::richtext::ckeditor4
  #
  #    mode: wysiwyg, source
  #    skin: moono, kama
  #    extraPlugins: tcl-list, is converted to comma list for js
  #
  ###########################################################
  Class create richtext::ckeditor4 -superclass richtext -parameter {
    {mode wysiwyg}
    {skin "bootstrapck,/resources/xowiki/ckeditor4/skins/bootstrapck/"}
    {toolbar Full}
    {CSSclass xowiki-ckeditor}
    {uiColor ""}
    {allowedContent ""}
    {CSSclass xowiki-ckeditor}
    {customConfig "config.js"}
    {callback "/* callback code */"}
    {destroy_callback "/* callback code */"}
    {submit_callback ""}
    {extraPlugins ""}
    {extraAllowedContent {*(*)}}
    {ck_package standard}
    {templatesFiles ""}
    {templates ""}
    {contentsCss /resources/xowiki/ck_contents.css}
    {imageSelectorDialog /xowiki/ckeditor-images/}
    {additionalConfigOptions ""}
  }
  richtext::ckeditor4 set editor_mixin 1

  richtext::ckeditor4 instproc initialize {} {
    switch -- ${:displayMode} {
      inplace { append :help_text " #xowiki.ckeip_help#" }
    }
    next
    set :widget_type richtext
    # Mangle the id to make it compatible with jQuery; most probably
    # not optimal and just a temporary solution
    regsub -all -- {[.:-]} ${:id} "" id
    :id $id
  }

  richtext::ckeditor4 instproc js_image_helper {} {
    set path [${:object} pretty_link]
    append js \
        [subst -novariables {
          function xowiki_image_callback(editor) {
            if (typeof editor != "undefined") {
              $(editor.element.$.form).submit(function(e) {
                calc_image_tags_to_wiki_image_links(this);
              });
              editor.setData(calc_wiki_image_links_to_image_tags('[set path]',editor.getData()));
            }
          }
        }] {
          function calc_image_tags_to_wiki_image_links(form) {
            var calc = function() {
              var wiki_link = $(this).attr('alt');
              $(this).replaceWith('[['+wiki_link+']]');
            }
            $(form).find('iframe').each(function() {
              $(this).contents().find('img[type="wikilink"]').each(calc);
            });

            $(form).find('textarea.ckeip').each(function() {
              var contents = $('<div>'+this.value+'</div>');
              contents.find('img[type="wikilink"]').each(calc);
              this.value = contents.html();
            });
            return true;
          }

          function calc_image_tags_to_wiki_image_links_inline(e) {
            var data = $('<div>'+CKEDITOR.instances[e].getData()+'</div>');
            data.find('img[type="wikilink"]').each( function() {
              var wiki_link = $(this).attr('alt');
              $(this).replaceWith('[['+wiki_link+']]');
            });
            CKEDITOR.instances[e].setData(data.html());
            CKEDITOR.instances[e].updateElement();
          }

          function calc_wiki_image_links_to_image_tags(path, text) {
            // console.log('path = <' + path + '>');
            var regex_wikilink = new RegExp('(\\[\\[.SELF./image:)(.*?)(\\]\\])', 'g');
            text = text.replace(regex_wikilink,'<img src="'+path+'/file:$2?m=download"  alt=".SELF./image:$2" type="wikilink"  />');
            return text;
          }
        }
    ::xo::Page requireJS $js
  }

  richtext::ckeditor4 instproc pathNames {fileNames} {
    set result [list]
    foreach fn $fileNames {
      if {[regexp {^[./]} $fn]} {
        append result $fn
      } else {
        append result "/resources/xowiki/$fn"
      }
    }
    return $result
  }

  richtext::ckeditor4 instproc render_input {} {
    set disabled [:is_disabled]
    set is_repeat_template [:is_repeat_template_p]

    # :msg "${:id} ${:name} - $is_repeat_template"

    if {$is_repeat_template} {
      set :data-repeat-template-id ${:id}
    }

    # if value is empty, we need something to be clickable for display mode inplace
    if {[:value] eq "" && ${:displayMode} eq "inplace"} {
      :value "&nbsp;"
    }

    if {![:istype ::xowiki::formfield::richtext] || ($disabled && !$is_repeat_template)} {
      :render_richtext_as_div
    } else {

      template::head::add_javascript -src urn:ad:js:jquery
      try {
        #
        # Try to use the ckeditor from the richtext-ckeditor4
        # installation.
        #
        # There seems to be something broken on 4.9.2 version on the
        # CDN. If we do not use standard-all, then we see an error
        # about a missing
        # ".../4.9.2/full/plugins/iframedialog/plugin.js". There
        # exists a default "iframe" and a "iframedialog" plugin for
        # ckeditor4, the latter is not included in the standard builds
        # (only in "-all").
        #
        # UPDATE July 2021: The "*-all" ckpackages are gone for newer
        # versions of CKEditor (e.g. 4.16.*) and it is unlikely that
        # it will be revived for the standard packages. One can
        # download the "iframedialog" plugin still from the addons
        #
        #    https://ckeditor.com/cke4/addon/iframedialog
        #
        # and add it manually to the downloaded tree in e.g.
        #
        #   richtext-ckeditor4/www/resources/4.16.1/standard/plugins/
        #
        # For the time being, we remove the "xowikiimage" plugin from
        # the extraPlugins to make it working out of the box. This
        # plugin should be rewritten using the current dialogs of
        # ckeditor.
        #
        ::richtext::ckeditor4::add_editor \
            -order 90 \
            -ck_package ${:ck_package} \
            -adapters "jquery.js"

      } trap {TCL LOOKUP COMMAND} {errorMsg} {
        #
        # If for whatever reason, richtext-ckeditor4 is not available,
        # bail out and tell the user to install.
        #

        error "Please install the package: richtext-ckeditor4"
      }

      #
      # In contrary to the documentation, ckeditor4 names instances
      # after the id, not the name.
      #
      set id ${:id}
      set name ${:name}
      set package_id [${:object} package_id]

      # Earlier versions required the plugin "sourcedialog" in
      # "inline" mode. Not sure why. This plugin was removed from
      # CKEditor.
      #if {${:displayMode} eq "inline"} {
      #  lappend :extraPlugins sourcedialog
      #}

      if {"xowikiimage" in ${:extraPlugins}} {
        :js_image_helper
        set ready_callback "xowiki_image_callback(CKEDITOR.instances\['$id'\]);"
        set ready_callback2 {xowiki_image_callback(e.editor);}
      } else {
        set ready_callback "/*none*/;"
        set ready_callback2 $ready_callback
        set submit_callback "/*none*/;"
      }

      #
      # Append dimensions (when available) in JSON notation.
      #
      set dimensions {}
      if {[info exists :height]} {
        lappend dimensions [subst {"height": "${:height}"}]
      }
      if {[info exists :width]} {
        lappend dimensions [subst {"width": "${:width}"}]
      }
      if {[llength $dimensions] > 0} {
        set dimensions [join $dimensions ,],
      }

      set options [subst {
        $dimensions
        ${:additionalConfigOptions}
        toolbar : '${:toolbar}',
        uiColor: '${:uiColor}',
        language: '[::xo::cc lang]',
        skin: '${:skin}',
        startupMode: '${:mode}',
        disableNativeSpellChecker: false,
        parent_id: '[${:object} item_id]',
        package_url: '[::$package_id package_url]',
        extraPlugins: '[join ${:extraPlugins} ,]',
        extraAllowedContent: '${:extraAllowedContent}',
        contentsCss: '${:contentsCss}',
        imageSelectorDialog: '[:imageSelectorDialog]?parent_id=[${:object} item_id]',
        ready_callback: '$ready_callback2',
        customConfig: '${:customConfig}',
        textarea_id: id
      }]
      if {${:allowedContent} ne ""} {
        #
        # Syntax rules:
        # https://ckeditor.com/docs/ckeditor4/latest/guide/dev_allowed_content_rules.html#string-format
        #
        if {${:allowedContent} in {true false}} {
          append options "  , allowedContent: ${:allowedContent}\n"
        } else {
          append options "  , allowedContent: '${:allowedContent}'\n"
        }
      }
      if {${:templatesFiles} ne ""} {
        append options "  , templates_files: \['[join [:pathNames ${:templatesFiles}] ',' ]' \]\n"
      }
      if {${:templates} ne ""} {
        append options "  , templates: '${:templates}'\n"
      }

      #set parent [[${:object} package_id] get_page_from_item_or_revision_id [${:object} parent_id]];# ???

      if {${:displayMode} eq "inplace"} {

        lappend :CSSclass ckeip
        ::xo::Page requireJS "/resources/xowiki/ckeip.js"

        ::xo::Page requireJS [subst -nocommands {
          function load_$id (id) {
            // must use id provided as argument
            \$('#' + id).ckeip(function() { ${:callback}}, {
              name: '$name',
              ckeditor_config: {
                $options,
                destroy_callback: function() { ${:destroy_callback} }
              }
            });
          }
        }]
        if {!$is_repeat_template} {
          ::xo::Page requireJS [subst -nocommands {
            \$(document).ready(function() {
              CKEDITOR.plugins.addExternal( 'xowikiimage', '/resources/xowiki/ckeditor4/plugins/xowikiimage/', 'plugin.js' );
              if (\$('#$id').parents('.repeatable').length != 0) {
                if (\$('#$id').is(':visible')) {
                  load_$id ('$id');
                }
              } else {
                //this is not inside a repeatable container, load normally
                load_$id ('$id');
              }
            } );
          }]
        }
        :render_richtext_as_div
      } elseif {${:displayMode} eq "inline"} {
        if {"xowikiimage" in ${:extraPlugins}} {
          set ready_callback "xowiki_image_callback(CKEDITOR.instances\['$id'\]);"
          set submit_callback "calc_image_tags_to_wiki_image_links_inline('$id');"
        }

        set submit_callback "$submit_callback ${:submit_callback}"
        ::xo::Page requireJS [subst {
          function load_$id (id) {
            CKEDITOR.inline(id, {
              on: {
                instanceReady: function(e) {
                  \$(e.editor.element.\$).attr('title', '${:label}');
                  \$(e.editor.element.\$.form).submit(function(e) {
                    $submit_callback
                  });
                }
              },
              $options
            });
          }
        }]
        if {!$is_repeat_template} {
          ::xo::Page requireJS [subst {
            \$(document).ready(function() {
              CKEDITOR.plugins.addExternal( 'xowikiimage', '/resources/xowiki/ckeditor4/plugins/xowikiimage/', 'plugin.js' );
              if (\$('#$id').parents('.repeatable').length != 0) {
                if (\$('#$id').is(':visible')) {
                  load_$id ('$id');
                }
              } else {
                //this is not inside a repeatable container, load normally
                load_$id ('$id');
              }
              $ready_callback
            });
          }]
        }
        next
      } else {
        ::xo::Page requireJS [subst -nocommands {
          function load_$id (id) {
            // must use id provided as argument
            \$('#' + id).ckeditor(function() { ${:callback} }, {$options});
          }
        }]
        if {!$is_repeat_template} {
          ::xo::Page requireJS [subst -nocommands {
            \$(document).ready(function() {
              CKEDITOR.plugins.addExternal( 'xowikiimage', '/resources/xowiki/ckeditor4/plugins/xowikiimage/', 'plugin.js' );
              load_$id ('$id');
              $ready_callback
              //CKEDITOR.instances['$id'].on('instanceReady',function(e) {$ready_callback});
            });
          }]
        }
        next
      }
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::richtext::wym
  #
  ###########################################################
  Class create richtext::wym -superclass richtext -parameter {
    {CSSclass wymeditor}
    width
    height
    {skin silver}
    {plugins "hovertools resizable fullscreen"}
  }
  richtext::wym set editor_mixin 1
  richtext::wym instproc initialize {} {
    next
    set :widget_type richtext
  }
  richtext::wym instproc render_input {} {
    set disabled [:is_disabled]
    if {![:istype ::xowiki::formfield::richtext] || $disabled } {
      :render_richtext_as_div
    } else {
      ::xo::Page requireCSS "/resources/xowiki/wymeditor/skins/default/screen.css"
      ::xo::Page requireJS urn:ad:js:jquery
      ::xo::Page requireJS  "/resources/xowiki/wymeditor/jquery.wymeditor.pack.js"
      set postinit ""
      foreach plugin {hovertools resizable fullscreen embed} {
        if {$plugin in [:plugins]} {
          switch -- $plugin {
            embed {}
            resizable {
              ::xo::Page requireJS  urn:ad:js:jquery-ui
              append postinit "wym.${plugin}();\n"
            }
            default {append postinit "wym.${plugin}();\n"}
          }
          ::xo::Page requireJS  "/resources/xowiki/wymeditor/plugins/$plugin/jquery.wymeditor.$plugin.js"
        }
      }
      regsub -all -- {[.:]} ${:id} {\\\\&} JID

      # possible skins are per in the distribution: "default", "sliver", "minimal" and "twopanels"
      set config [list "skin: '[:skin]'"]

      #:msg "wym, h [info exists :height] || w [info exists :width]"
      if {[info exists :height] || [info exists :width]} {
        set height_cmd ""
        set width_cmd ""
        if {[info exists :height]} {set height_cmd "jQuery(wym._box).find(wym._options.iframeSelector).css('height','[:height]');"}
        if {[info exists :width]}  {set width_cmd "wym_box.css('width', '[:width]');"}
        set postInit [subst -nocommand -nobackslash {
          postInit: function(wym) {
            wym_box = jQuery(".wym_box");
            $height_cmd
            $width_cmd
            $postinit
          }}]
        lappend config $postInit
      }
      if {$config ne ""} {
        set config \{[join $config ,]\}
      }
      ::xo::Page requireJS [subst -nocommand -nobackslash {
        jQuery(function() {
          jQuery("#$JID").wymeditor($config);
        });
      }]

      next
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::richtext::xinha
  #
  ###########################################################

  Class create richtext::xinha -superclass richtext -parameter {
    javascript
    {height}
    {style}
    {wiki_p true}
    {slim false}
    {CSSclass xinha}
    extraPlugins
  }
  richtext::xinha set editor_mixin 1
  richtext::xinha instproc initialize {} {
    switch -- ${:displayMode} {
      inplace {
        ::xo::Page requireJS  "/resources/xowiki/xinha-inplace.js"
        if {![info exists ::__xinha_inplace_init_done]} {
          template::add_body_handler -event onload -script "xinha.inplace.init();"
          set ::__xinha_inplace_init_done 1
        }
      }
      inline { error "inline is not supported for xinha"}
    }

    next
    set :widget_type richtext
    if {![info exists :extraPlugins]} {
      set :plugins \
          [parameter::get -parameter "XowikiXinhaDefaultPlugins" \
               -default [parameter::get_from_package_key \
                             -package_key "acs-templating" \
                             -parameter "XinhaDefaultPlugins"]]
    } else {
      set :plugins ${:extraPlugins}
    }
    set :options [:get_attributes editor plugins width height folder_id script_dir javascript wiki_p]
    # for the time being, we can't set the defaults via parameter,
    # but only manually, since the editor is used as a mixin, the parameter
    # would have precedence over the defaults of subclasses
    if {![info exists :slim]} {set :slim false}
    if {![info exists :style]} {set :style "width: 100%;"}
    if {![info exists :height]} {set :height 350px}
    if {![info exists :wiki_p]} {set :wiki_p 1}
    if {${:slim}} {
      lappend :options javascript {
        xinha_config.toolbar  = [['popupeditor', 'formatblock', 'bold','italic','createlink','insertimage'],
                                 ['separator','insertorderedlist','insertunorderedlist','outdent','indent'],
                                 ['separator','killword','removeformat','htmlmode']
                                ];
      }
    }
  }

  richtext::xinha instproc render_input {} {
    set disabled [:is_disabled]
    if {![:istype ::xowiki::formfield::richtext] || $disabled} {
      :render_richtext_as_div
    } else {
      #
      # required CSP directives for Xinha
      #
      security::csp::require script-src 'unsafe-eval'
      security::csp::require script-src 'unsafe-inline'

      # we use for the time being the initialization of xinha based on
      # the blank master
      set ::acs_blank_master(xinha) 1
      set quoted [list]
      foreach e [:plugins] {lappend quoted '$e'}
      set ::acs_blank_master(xinha.plugins) [join $quoted ", "]

      array set o ${:options}
      set xinha_options ""
      foreach e {width height folder_id fs_package_id file_types attach_parent_id wiki_p package_id} {
        if {[info exists o($e)]} {
          append xinha_options "xinha_config.$e = '$o($e)';\n"
        }
      }
      append xinha_options "xinha_config.package_id = '[::xo::cc package_id]';\n"
      if {[info exists o(javascript)]} {
        append xinha_options $o(javascript) \n
      }
      set ::acs_blank_master(xinha.options) $xinha_options
      lappend ::acs_blank_master__htmlareas ${:id}

      if {${:displayMode} eq "inplace"} {
        ::html::div [:get_attributes id name {CSSclass class} disabled] {
          set href \#
          ::html::a -style "float: right;" -class edit-item-button -href $href -id ${:id}-edit {
            ::html::t -disableOutputEscaping &nbsp;
          }
          template::add_event_listener \
              -id ${:id}-edit \
              -script [subst {xinha.inplace.openEditor('${:id}');}]

          ::html::div -id "${:id}__CONTENT__" {
            ::html::t -disableOutputEscaping  [:value]
          }
        }
        set :hiddenid ${:id}__HIDDEN__
        set :type hidden
        ::html::input [:get_attributes {hiddenid id} name type value] {}
      } else {
        #::html::div [:get_attributes id name cols rows style {CSSclass class} disabled] {}
        next
      }
    }
  }

}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
