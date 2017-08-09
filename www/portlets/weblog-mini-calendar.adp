<table class="mini-calendar weblog-mini-calendar" cellpadding="0" cellspacing="0">
  <tr>
    <td colspan="4">
      <table class="header" cellspacing="0" cellpadding="0">
        <tr>
            <td class="back">
	      <if @prev_month_url@ ne "">
              <a href="@prev_month_url@"><img border="0" src="/resources/acs-subsite/left.gif" width="13" height="13" alt="#acs-kernel.common_previous#"></a>
	    </if>
            </td>
            <td class="current_view" colspan="2">@curr_month@ @year@</td>
            <td class="forward">
	      <if @next_month_url@ ne "">
              <a href="@next_month_url@"><img border="0" src="/resources/acs-subsite/right.gif" width="13" height="13" alt="#acs-kernel.common_next#"></a>
	    </if>
            </td>
        </tr>
      </table>
    </td>
  </tr>
  
  <tr>
    <td colspan="4">
      <table id="at-a-glance" cellspacing="0" cellpadding="0">

          <tr class="days">
            <multiple name="days_of_week">
              <td>@days_of_week.day_short@</td>
            </multiple>
          </tr>
      
          <multiple name="days">
            <if @days.beginning_of_week_p;literal@ true>
              <tr>
            </if>
        
	    <if @days.count@ ne "">
                <td class="@days.class@" id="@days.id@">
                <span style='font-size: 80%;'>@days.count@</span> @days.day_number@</td>
             </if><else>
                <td class="@days.class@"> @days.day_number@</td>
             </else>
        
            <if @days.end_of_week_p;literal@ true>
              </tr>
            </if>
          </multiple>
 
      </table>
  
    </td>
  </tr>
 </table>
