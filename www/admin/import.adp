<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>  

<formtemplate id="upload_form">
  <table cellspacing="2" cellpadding="2" border="0">
    <tr class="form-element">
      <if @formerror.upload_file@ not nil>
	<td class="form-widget-error">
      </if>
      <else>
	<td class="form-widget">
      </else>
      <formwidget id="upload_file">
	<formerror id="upload_file">
	  <div class="form-error">@formerror.upload_file@</div>
	</formerror>
</td>
</tr>
<tr class="form-element">
  <td class="form-widget" colspan="2" align="center">
    <formwidget id="ok_btn">
  </td>
</tr>
</table>
</formtemplate>
@msg;noquote@
<br><a href="../">Index</a>

