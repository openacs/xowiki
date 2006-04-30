<div class="portlet-title">
<span><a href='@link@'>@name@</a></span>
</div>
<div class="portlet">
  <div class='weblog'>
    <if @filter_msg@ ne "">
      <div class='filter'>@filter_msg@</div>
    </if> 
    @content;noquote@
    <if @prev_p@>
      <a href='@prev_page@'><img border=0 src='/resources/acs-subsite/left.gif' 
       alt='previous page' style='float: left;  top: 0px; '></a>
    </if>
    <if @next_p@>
      <a href='@next_page@'><img border=0 src='/resources/acs-subsite/right.gif' 
       alt='next page' style='float: right;  top: 0px; '></a><p>
     </if>
  </div>
</div>
